// Check that --offload-new-driver + -save-temps emits a device .s binding for AMDGPU HIP.
// The fix adds a companion BackendJobAction(BC, TY_PP_Asm) so users get the device
// assembly file for debugging, which the new offload pipeline otherwise skips.

// REQUIRES: amdgpu-registered-target
// REQUIRES: x86-registered-target

// -fno-gpu-rdc + -save-temps: device .s action must appear.
// RUN: %clang -### -ccc-print-bindings --target=x86_64-linux-gnu -nogpulib \
// RUN:   -save-temps --offload-new-driver -nogpuinc --offload-arch=gfx906 -c %s 2>&1 | \
// RUN:   FileCheck -check-prefix=NORDC-ST %s

//      NORDC-ST: # "amdgcn-amd-amdhsa" - "clang", inputs: ["[[INPUT:.+]]"], output: "[[HIPI:.+\.hipi]]"
// NORDC-ST-NEXT: # "amdgcn-amd-amdhsa" - "clang", inputs: ["[[HIPI]]"], output: "[[TMP_BC:.+\.tmp\.bc]]"
// NORDC-ST-NEXT: # "amdgcn-amd-amdhsa" - "clang", inputs: ["[[TMP_BC]]"], output: "[[BC:.+\.bc]]"
// NORDC-ST-NEXT: # "amdgcn-amd-amdhsa" - "clang", inputs: ["[[BC]]"], output: "[[ASM:.+\.s]]"
//      NORDC-ST: # "amdgcn-amd-amdhsa" - "Offload::Packager", inputs: ["[[BC]]"], output: {{.+}}

// -fgpu-rdc + -save-temps: device .s action must also appear.
// RUN: %clang -### -ccc-print-bindings --target=x86_64-linux-gnu -nogpulib \
// RUN:   -save-temps --offload-new-driver -nogpuinc --offload-arch=gfx906 -fgpu-rdc -c %s 2>&1 | \
// RUN:   FileCheck -check-prefix=RDC-ST %s

//      RDC-ST: # "amdgcn-amd-amdhsa" - "clang", inputs: ["[[INPUT:.+]]"], output: "[[HIPI:.+\.hipi]]"
// RDC-ST-NEXT: # "amdgcn-amd-amdhsa" - "clang", inputs: ["[[HIPI]]"], output: "[[TMP_BC:.+\.tmp\.bc]]"
// RDC-ST-NEXT: # "amdgcn-amd-amdhsa" - "clang", inputs: ["[[TMP_BC]]"], output: "[[BC:.+\.bc]]"
// RDC-ST-NEXT: # "amdgcn-amd-amdhsa" - "clang", inputs: ["[[BC]]"], output: "[[ASM:.+\.s]]"
//      RDC-ST: # "x86_64-unknown-linux-gnu" - "Offload::Packager", inputs: ["[[BC]]"], output: {{.+}}

// Without -save-temps: no device .s action.
// RUN: %clang -### -ccc-print-bindings --target=x86_64-linux-gnu -nogpulib \
// RUN:   --offload-new-driver -nogpuinc --offload-arch=gfx906 -c %s 2>&1 | \
// RUN:   FileCheck -check-prefix=NO-ST %s

// NO-ST-NOT: # "amdgcn-amd-amdhsa" - "clang", inputs: {{.*}}, output: "{{.*\.s}}"

// -save-temps + -emit-llvm: -emit-llvm implies IR output, no .s action expected.
// RUN: %clang -### -ccc-print-bindings --target=x86_64-linux-gnu -nogpulib \
// RUN:   -save-temps --offload-new-driver -nogpuinc --offload-arch=gfx906 -emit-llvm -c %s 2>&1 | \
// RUN:   FileCheck -check-prefix=EMIT-LLVM %s

// EMIT-LLVM-NOT: # "amdgcn-amd-amdhsa" - "clang", inputs: {{.*}}, output: "{{.*\.s}}"

// -save-temps + multiple archs: one device .s per arch.
// RUN: %clang -### -ccc-print-bindings --target=x86_64-linux-gnu -nogpulib \
// RUN:   -save-temps --offload-new-driver -nogpuinc \
// RUN:   --offload-arch=gfx906 --offload-arch=gfx1010 -c %s 2>&1 | \
// RUN:   FileCheck -check-prefix=MULTI-ARCH %s

// MULTI-ARCH: # "amdgcn-amd-amdhsa" - "clang", inputs: {{.*}}, output: "[[ASM906:.+gfx906.+\.s]]"
// MULTI-ARCH: # "amdgcn-amd-amdhsa" - "clang", inputs: {{.*}}, output: "[[ASM1010:.+gfx1010.+\.s]]"
