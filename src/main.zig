const std = @import("std");
const log = std.log;

pub fn main() !void {}
pub const LZCompression: type = struct {
    pub fn compression(filePath: []const u8, allocator: std.mem.Allocator) !void {
        var file = try std.fs.openFileAbsolute(filePath, .{});
        defer file.close();
        try compressFile(file, allocator);
    }

    pub fn compressFile(file: std.fs.File, allocator: std.mem.Allocator) !void {
        std.log.debug("Starting Compression...", .{});
        var buffer: [64000]u8 = undefined;
        try file.seekTo(0);

        std.log.debug("Reading File...", .{});
        const bytes_to_read = try file.readAll(&buffer);

        var map = std.AutoHashMap(u32, u16).init(
            allocator,
        );
        defer map.deinit();
        defer map.clearAndFree();

        var write_array = std.ArrayList(u8).init(
            allocator,
        );
        defer write_array.deinit();
        defer write_array.clearAndFree();

        var bytes_skipped: usize = 0;
        var literal_bytes_count: usize = 0;
        var first_literal: bool = true;
        var start_literal: u16 = 0;
        var end_literal: u16 = 0;
        var bytes_recorded: usize = 0;

        var index: u16 = 0;
        while (index < bytes_to_read) {
            // log.debug("index: {} | first_literal: {}", .{ index, first_literal });
            const tuple = try findLongestMatch(&buffer, index, &map);
            if (tuple.match_found) {
                // log.debug("found..", .{});
                index += tuple.match_length;
                first_literal = true;
                bytes_skipped += tuple.match_length;

                //Here we add in logic for creating the token byte
                //TODO make this instead write into a file later
                var generate_byte: std.ArrayList(u8) = std.ArrayList(u8).init(allocator);
                defer generate_byte.deinit();
                defer generate_byte.clearAndFree();

                const written_bytes = try generateByte(&buffer, start_literal, end_literal, tuple, &generate_byte);
                bytes_recorded += written_bytes.len;
                try write_array.writer().writeAll(written_bytes);

                literal_bytes_count = 0;
            } else {
                if (first_literal) {
                    first_literal = false;
                    start_literal = index;
                }
                end_literal = index;
                literal_bytes_count += 1;
                index += 1;
            }
        }
        log.debug("Total Bytes: {} | Bytes skipped: {} | Compressed Bytes: {}", .{ bytes_to_read, bytes_skipped, bytes_to_read - bytes_skipped });
        log.debug("Original Byte Length: {} || Compressed Byte Length: {}", .{ bytes_to_read, bytes_recorded });
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
    fn generateByte(buffer: *[64000]u8, literal_start: u16, literal_end: u16, offset: LZTuple, array: *std.ArrayList(u8)) ![]u8 {
        var literal_count: usize = literal_end - literal_start;
        var token_literal_count: usize = 0;
        var token_offset_count: usize = 0;

        //Setting the literal bytes in token
        var high_nibble: u8 = 0;
        if (literal_count >= 15) {
            high_nibble = 15 << 4;
            literal_count -= 15;
            //This is setting the literal count overflow, in case there are more literals than is supported in 4 bits
            while (literal_count >= 255) {
                try array.append(255);
                literal_count -= 255;
                token_literal_count += 1;
            }
            try array.append(@truncate(literal_count));
        } else {
            //If there is no extra overflow in literal count, then just set the high-nibble
            high_nibble = @truncate(literal_count);
            high_nibble <<= 4;
        }

        //Adding in the actual literal bytes
        for (buffer[literal_start..literal_end]) |byte| {
            try array.append(byte);
        }

        //Counting offset
        const offset_count = offset.match_offset;
        //offset count is stored in little endian (should not be more than 2 bytes, as the offset is set to that size)

        try array.append(@truncate(offset_count & 0x00FF));
        try array.append(@truncate(offset_count & 0xFF00));

        // if (offset_count > 255) {
        //     while (offset_count >= 255) : (offset_count -= 255) {
        //         try array.append(255);
        //         log.debug("Array Length is: {}", .{array.items.len});
        //     }
        // }
        try array.append(@truncate(offset_count));

        var low_nibble: u8 = 0;
        var offset_length = offset.match_length;
        //Storing the offset length
        //The issue is storing this match offset, it is using more than 2 bytes
        if (offset.match_length >= 15) {
            low_nibble = 15;
            offset_length -= 15;
            while (offset_length >= 255) : (offset_length -= 255) {
                try array.append(255);
                token_offset_count += 1;
            }
            try array.append(@truncate(offset_length));
        } else {
            low_nibble = @truncate(offset_length);
        }
        try array.insert(0, high_nibble | low_nibble);
        return array.items;
    }
};
pub const LZTuple: type = struct { match_found: bool, match_offset: u16, match_length: u16 };
