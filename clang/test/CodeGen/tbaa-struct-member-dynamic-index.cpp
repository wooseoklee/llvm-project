// RUN: %clang_cc1 -triple x86_64-linux -O1 -emit-llvm -o - %s | FileCheck %s
// RUN: %clang_cc1 -triple x86_64-linux -O1 -new-struct-path-tbaa -emit-llvm -o - %s | \
// RUN:     FileCheck -check-prefix=CHECK-NEW %s
//
// Test that a dynamic array subscript through a struct member pointer,
// (&struct.x)[runtime_index], does NOT carry struct-member-specific TBAA.
//
// At runtime the index can reach any member of the struct, so the load
// must carry MayAlias TBAA (omnipotent char), not the x-member tag
// {uint2_struct, int, offset=0}.
//
// If the load incorrectly carries x-member TBAA (offset=0), then alias
// analysis returns NoAlias between the load and a store to y (offset=4),
// allowing DSE to incorrectly eliminate the y-member store.

struct uint2 { unsigned x, y; };

void test(uint2 *s, unsigned idx, unsigned val_x, unsigned val_y, unsigned *out) {
    s->x = val_x;  // store to x-member, TBAA offset=0
    s->y = val_y;  // store to y-member, TBAA offset=4

    // (&s->x)[idx]: takes address of .x, then indexes with a runtime value.
    // When idx==1, accesses y-member (offset=4).
    // The load must carry MayAlias TBAA, not x-member TBAA (offset=0).
    *out = (&s->x)[idx];
}

// CHECK-LABEL: define {{.*}} @_Z4test
// Store to x-member: struct-path TBAA at offset=0 is correct.
// CHECK: store i32 %val_x, ptr %s{{.*}}, !tbaa [[TBAA_X:![0-9]+]]
// Store to y-member: struct-path TBAA at offset=4 is correct.
// CHECK: store i32 %val_y, ptr %{{.*}}, !tbaa [[TBAA_Y:![0-9]+]]
// Dynamic-index load: must carry MayAlias TBAA (omnipotent char).
// CHECK: load i32, ptr %arrayidx{{.*}}, !tbaa [[TBAA_LOAD:![0-9]+]]

// Metadata definitions (use CHECK-DAG since order may vary):
// TBAA_X: struct-path at offset=0 {uint2_struct, int, 0}
// CHECK-DAG: [[TBAA_X]] = !{[[UINT2:![0-9]+]], [[INT:![0-9]+]], i64 0}
// TBAA_Y: struct-path at offset=4 {uint2_struct, int, 4}
// CHECK-DAG: [[TBAA_Y]] = !{[[UINT2]], [[INT]], i64 4}
// TBAA_LOAD: omnipotent char (MayAlias) {char, char, 0}
// CHECK-DAG: [[TBAA_LOAD]] = !{[[CHAR:![0-9]+]], [[CHAR]], i64 0}
// CHECK-DAG: [[CHAR]] = !{!"omnipotent char",

// CHECK-NEW-LABEL: define {{.*}} @_Z4test
// Store to x-member: new struct-path TBAA {uint2_type, int_type, offset=0, size=4}.
// CHECK-NEW: store i32 %val_x, ptr %s{{.*}}, !tbaa [[TBAA_X_NEW:![0-9]+]]
// Store to y-member: new struct-path TBAA {uint2_type, int_type, offset=4, size=4}.
// CHECK-NEW: store i32 %val_y, ptr %{{.*}}, !tbaa [[TBAA_Y_NEW:![0-9]+]]
// Dynamic-index load: must carry MayAlias TBAA (omnipotent char, size=0).
// CHECK-NEW: load i32, ptr %arrayidx{{.*}}, !tbaa [[TBAA_LOAD_NEW:![0-9]+]]

// CHECK-NEW-DAG: [[TBAA_X_NEW]] = !{[[UINT2_NEW:![0-9]+]], [[INT_NEW:![0-9]+]], i64 0, i64 4}
// CHECK-NEW-DAG: [[TBAA_Y_NEW]] = !{[[UINT2_NEW]], [[INT_NEW]], i64 4, i64 4}
// CHECK-NEW-DAG: [[TBAA_LOAD_NEW]] = !{[[CHAR_NEW:![0-9]+]], [[CHAR_NEW]], i64 0, i64 0}
// CHECK-NEW-DAG: [[CHAR_NEW]] = !{[[ROOT_NEW:![0-9]+]], i64 1, !"omnipotent char"}
// CHECK-NEW-DAG: [[INT_NEW]] = !{[[CHAR_NEW]], i64 4, !"int"}
// CHECK-NEW-DAG: [[UINT2_NEW]] = !{[[CHAR_NEW]], i64 8, !"_ZTS5uint2",
