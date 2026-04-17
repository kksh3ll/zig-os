const std = @import("std");
const Target = std.Target;
const TargetQuery = Target.Query;

fn addTests(
    b: *std.Build,
    test_step: *std.Build.Step,
    dir_path: []const u8,
) !void {
    const tests = b.addTest(.{
        .root_source_file = b.path(dir_path),
        .target = b.standardTargetOptions(.{}),
        .optimize = .Debug,
    });
    const run_tests = b.addRunArtifact(tests);
    test_step.dependOn(&run_tests.step);
}

pub fn build(b: *std.Build) void {
    const target_query = TargetQuery{
        .cpu_arch = Target.Cpu.Arch.x86_64,
        .os_tag = Target.Os.Tag.freestanding,
        .abi = Target.Abi.none,
        .cpu_features_add = std.Target.Cpu.Feature.Set.empty,
        .cpu_features_sub = std.Target.Cpu.Feature.Set.empty,
    };

    const target = b.resolveTargetQuery(target_query);
    const optimize = b.standardOptimizeOption(.{});

    // Setting our kernel:
    const kernel_mod = b.addModule("kernel", .{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    kernel_mod.addAssemblyFile(b.path("src/asm.S"));


    const kernel = b.addExecutable(.{
        .name = "zig-os",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .code_model = .kernel,
    });
    kernel.linker_script = b.path("src/linker.ld");
    kernel.pie = false;

    const boot_asm = b.addAssembly(.{
        .name = "boot",
        .source_file = b.path("src/boot.s"),
        .target = target,
        .optimize = optimize,
    });
    kernel.addObject(boot_asm);

    b.installArtifact(kernel);

    const iso_step = b.step("iso", "Create bootable ISO");
    const iso_cmd = b.addSystemCommand(&.{
        "bash", "-c",
        \\set -e
        \\rm -rf zig-out/iso_root
        \\mkdir -p zig-out/iso_root/boot/grub/i386-pc
        \\cp zig-out/bin/zig-os zig-out/iso_root/boot/
        \\cp boot/grub/grub.cfg zig-out/iso_root/boot/grub/
        \\grub-mkimage -O i386-pc -o /tmp/core.img -p "(cd)/boot/grub" -d /usr/lib/grub/i386-pc biosdisk iso9660 multiboot2 normal
        \\cat /usr/lib/grub/i386-pc/cdboot.img /tmp/core.img > zig-out/iso_root/boot/grub/i386-pc/eltorito.img
        \\cp /usr/lib/grub/i386-pc/*.mod zig-out/iso_root/boot/grub/i386-pc/
        \\xorriso -as mkisofs -R -J -c boot/grub/boot.cat \
        \\    -b boot/grub/i386-pc/eltorito.img \
        \\    -no-emul-boot -boot-load-size 4 -boot-info-table \
        \\    -o zig-out/zig-os.iso zig-out/iso_root
    });
    iso_cmd.step.dependOn(b.getInstallStep());
    iso_step.dependOn(&iso_cmd.step);

    const run_cmd = b.addSystemCommand(&.{
        "qemu-system-x86_64",
        "-cdrom",
        "zig-out/zig-os.iso",
        "-m",
        "128M",
        "-serial",
        "stdio",
    });
    run_cmd.step.dependOn(iso_step);

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the OS in QEMU");
    run_step.dependOn(&run_cmd.step);

    const test_step = b.step("test", "Run all tests");
    addTests(b, test_step, "src/") catch |err| {
        std.debug.print("Error adding tests: {}\n", .{err});
        return;
    };
}
