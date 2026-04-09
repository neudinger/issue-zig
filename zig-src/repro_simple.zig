//! Compiler segfault: recursive comptime `@typeInfo` on self-referential struct
//! `zig build-exe repro_simple.zig`  →  Segmentation fault
const RecurseStruct = struct { a: *const RecurseStruct };

fn walk(comptime Type: type) void {
    @setEvalBranchQuota(2000);
    // Work fine with
    // @setEvalBranchQuota(1840);
    switch (@typeInfo(Type)) {
        .@"struct" => |i| inline for (i.fields) |f| walk(f.type),
        .pointer => |i| walk(i.child),
        else => {},
    }
}

comptime {
    walk(RecurseStruct);
}
pub fn main() void {}
