const std = @import("std");

pub fn main() !void {}
pub const LZCompression: type = struct {
    pub fn compression(filePath: []const u8) !void {
        var file = try std.fs.openFileAbsolute(filePath, .{});
        defer file.close();
        try compress(file);
    }
    pub fn compress(file: std.fs.File) !void {
        var buffer: [64000]u8 = undefined;
        try file.seekTo(0);

        const bytes_read = try file.readAll(&buffer);
        var bytes_skipped: usize = 0;

        var index: usize = 0;
        while (index < bytes_read) {
            const byte = buffer[index];
            const tuple = try findLongestMatch(buffer, index);
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
    fn findLongestMatch(buffer: [64000]u8, start_index: usize) !LZTuple {
        var search_index: u32 = 0;
        var longestMatch: LZTuple = LZTuple{ .match_found = false, .match_offset = 0, .match_length = 0 };
        while (search_index < start_index) : (search_index += 1) {
            const match: LZTuple = try getLongestMatch(buffer, search_index, start_index);

            if (!match.match_found) {
                continue;
            }

            if (match.match_length >= longestMatch.match_length) {
                longestMatch = match;
            }
        }
        return longestMatch;
    }

    fn getLongestMatch(buffer: [64000]u8, search_index: u32, start_index: usize) !LZTuple {
        var i: u32 = 0;
        while (start_index + i < buffer.len) : (i += 1) {
            if (buffer[search_index + i] == buffer[start_index + i]) {
                continue;
            }
            break;
        }
        return LZTuple{ .match_found = i >= 4, .match_offset = start_index - search_index, .match_length = i };
    }
};
pub const LZTuple: type = struct { match_found: bool, match_offset: usize, match_length: usize };
// pub const LZError = error{
//     ByteMatchExceeded,
// };
