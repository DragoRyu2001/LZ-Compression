const std = @import("std");

pub fn main() !void {}
pub const LZCompression: type = struct {
    pub fn compression(filePath: []const u8) !void {
        var file = try std.fs.openFileAbsolute(filePath, .{});
        defer file.close();

        var buffer: [100]u8 = undefined;
        try file.seekTo(0);
        const bytes_read = try file.readAll(&buffer);

        for (buffer, 0..) |byte, index| {
            var j: usize = index;
            while (j >= 0) : (j -= 1) {
                if (buffer[j] == byte) {}
            }
        }
    }
    fn findLongestMatch(buffer: *const []u8, start_index: usize) !LZTuple {
        search_index: u32 = 0;
        while(search_index < start_index) : (search_index+=1) {
            if(buffer[search_index] == buffer[start_index]) {
                
            }
        }
        return LZTuple{false, 0, 0};
    }
};
pub const LZTuple: type = struct { match_found: bool, match_offset: u32, match_length: u32 };
