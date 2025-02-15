const std = @import("std");

pub fn main() !void {}
pub const LZCompression: type = struct {
    pub fn compression(filePath: []const u8, allocator: std.mem.Allocator) !void {
        var file = try std.fs.openFileAbsolute(filePath, .{});
        defer file.close();
        try compressFile(file, allocator);
    }

    pub fn compressFile(file: std.fs.File, allocator: std.mem.Allocator) !void {
        var buffer: [64000]u8 = undefined;
        try file.seekTo(0);
        var map = std.AutoHashMap(u32, u16).init(
            allocator,
        );
        defer map.deinit();
        defer map.clearAndFree();

        var array = std.ArrayList(u8).init(
            allocator,
        );
        defer array.deinit();
        defer array.clearAndFree();

        const bytes_to_read = try file.readAll(&buffer);
        var bytes_skipped: usize = 0;
        var literal_bytes_count: usize = 0;
        var literal_bytes: [64000]u8 = undefined;
        var first_literal: bool = true;
        var start_literal: u16 = 0;
        var end_literal: u16 = 0;

        var index: u16 = 0;
        while (index < bytes_to_read) {
            const byte = buffer[index];
            const tuple = try findLongestMatch(&buffer, index, &map);
            if (tuple.match_found) {
                std.log.debug("Found tuple: {}", .{tuple});
                index += tuple.match_length;
                bytes_skipped += tuple.match_length;

                //Here we add in logic for creating the token byte
                try generateByte(&buffer, start_literal, end_literal, tuple, allocator);
                literal_bytes_count = 0;
                first_literal = true;
            } else {
                if (first_literal) {
                    first_literal = false;
                    start_literal = index;
                }
                end_literal = index;
                std.log.debug("Literal: {c}", .{byte});
                literal_bytes[literal_bytes_count] = byte;
                literal_bytes_count += 1;
                index += 1;
            }
        }
        std.log.debug("Total Bytes: {} | Bytes skipped: {} | Compressed Bytes: {}", .{ bytes_to_read, bytes_skipped, bytes_to_read - bytes_skipped });
    }

    fn findLongestMatch(buffer: *[64000]u8, start_index: u16, map: *std.AutoHashMap(u32, u16)) !LZTuple {
        const hash_key = try getHashKey(buffer, start_index);

        var longest_match: LZTuple = LZTuple{ .match_found = false, .match_offset = 0, .match_length = 0 };
        var longest_match_index: u16 = 0;

        if (map.contains(hash_key)) {
            longest_match_index = map.get(hash_key).?;
            longest_match = try getLongestMatch(buffer, longest_match_index, start_index);

            //we override the current position as the new value for the key, so that the offest remains tame
            longest_match_index = start_index;
        } else {
            var iterator: u16 = 0;
            longest_match_index = start_index;
            while (iterator < start_index) : (iterator += 1) {
                const match: LZTuple = try getLongestMatch(buffer, iterator, start_index);

                if (!match.match_found) {
                    continue;
                }

                if (match.match_length >= longest_match.match_length) {
                    longest_match_index = iterator;
                    longest_match = match;
                }
            }
        }
        try map.put(hash_key, longest_match_index);
        return longest_match;
    }

    fn getLongestMatch(buffer: *[64000]u8, search_index: u16, start_index: u16) !LZTuple {
        var i: u16 = 0;
        while (start_index + i < buffer.len) : (i += 1) {
            if (buffer[search_index + i] == buffer[start_index + i]) {
                continue;
            }
            break;
        }
        return LZTuple{ .match_found = i >= 4, .match_offset = start_index - search_index, .match_length = i };
    }

    fn getHashKey(buffer: *[64000]u8, index: usize) !u32 {
        var value: u32 = @as(u32, buffer[index]);
        value |= @as(u32, buffer[index + 1]) << 8;
        value |= @as(u32, buffer[index + 2]) << 16;
        value |= @as(u32, buffer[index + 3]) << 24;
        return value;
    }
    fn generateByte(buffer: *[64000]u8, literal_start: u16, literal_end: u16, offset: LZTuple, allocator: std.mem.Allocator) !void {
        var literal_count: usize = literal_end - literal_start;
        var array: std.ArrayList(u8) = std.ArrayList(u8).init(allocator);
        defer array.deinit();
        defer array.clearAndFree();

        //Setting the literal bytes in token
        var high_nibble: u8 = 0;
        if (literal_count >= 15) {
            high_nibble = 15 << 4;
            literal_count -= 15;
            while (literal_count >= 255) {
                try array.append(255);
                literal_count -= 255;
            }
            try array.append(@truncate(literal_count));
        } else {
            high_nibble = @truncate(literal_count);
            high_nibble <<= 4;
        }

        for (buffer[literal_start..literal_end]) |byte| {
            try array.append(byte);
        }

        var offset_count = offset.match_offset;
        if (offset_count > 255) {
            while (offset_count >= 255) : (offset_count -= 255) {
                try array.append(255);
            }
        }
        try array.append(@truncate(offset_count));

        var low_nibble: u8 = 0;
        var offset_length = offset.match_length;
        if (offset.match_length >= 15) {
            low_nibble = 15;
            offset_length -= 15;
            while (offset_length >= 255) : (offset_length -= 255) {
                try array.append(255);
            }
            try array.append(@truncate(offset_length));
        } else {
            low_nibble = @truncate(offset_length);
        }
        try array.insert(0, high_nibble | low_nibble);
        std.log.debug("Compressed Byte is:", .{});
        for (array.items) |byte| {
            std.log.debug("===||  {c}", .{byte});
        }
    }
};
pub const LZTuple: type = struct { match_found: bool, match_offset: u16, match_length: u16 };
pub const RandomNumber: comptime_int = 2654435761;
// pub const LZError = error{
//     ByteMatchExceeded,
// };
