	.arch armv8-a
	.arch_extension crc
	.arm
	.data
	.text
	.global main
	.type main , %function
main:
	push {r4, r5, r6, fp, lr}
	mov fp, sp
	sub  sp, sp, #8
.L12:
	ldr r4, =10
	str r4, [fp, #-8]
	ldr r4, =30
	str r4, [fp, #-4]
	ldr r4, [fp, #-8]
	ldr r5, =0
	sub  r6, r5, #5
	sub  r5, r4, r6
	ldr r4, [fp, #-4]
	add  r6, r4, r5
	ldr r4, =0
	sub  r5, r4, #5
	add  r4, r5, r6
	mov r0, r4
	sub  sp, fp, #0
	pop {r4, r5, r6, fp, lr}
	bx lr
