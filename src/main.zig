const std = @import("std");

pub fn main() !void {}
pub const LZCompression: type = struct {
    pub fn compression(filePath: []const u8, allocator: std.mem.Allocator) !void {
        var file = try std.fs.openFileAbsolute(filePath, .{});
        defer file.close();
        try compress(file, allocator);
    }

    pub fn compress(file: std.fs.File, allocator: std.mem.Allocator) !void {
        var buffer: [64000]u8 = undefined;
        try file.seekTo(0);
        var map = std.AutoHashMap(u32, u16).init(
            allocator,
        );
        defer map.clearAndFree();

        const bytes_read = try file.readAll(&buffer);
        var bytes_skipped: usize = 0;

        var index: u16 = 0;
        while (index < bytes_read) {
            const byte = buffer[index];
            const tuple = try findLongestMatch(&buffer, index, &map);
            if (tuple.match_found) {
                std.log.debug("Found tuple: {}", .{tuple});
                index += tuple.match_length;
                bytes_skipped += tuple.match_length;
            } else {
                std.log.debug("Literal: {c}", .{byte});
                index += 1;
            }
        }
        std.log.debug("Total Bytes: {} | Bytes skipped: {} | Compressed Bytes: {}", .{ bytes_read, bytes_skipped, bytes_read - bytes_skipped });
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

    fn getLongestMatch(buffer: *[64000]u8, search_index: u32, start_index: usize) !LZTuple {
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
};
pub const LZTuple: type = struct { match_found: bool, match_offset: usize, match_length: u16 };
pub const RandomNumber: comptime_int = 2654435761;
// pub const LZError = error{
//     ByteMatchExceeded,
// };
