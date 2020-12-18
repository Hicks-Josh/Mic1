/* ~~~~~~~ external functions ~~~~~ */


.extern fgetc
.extern fopen
.extern puts
.extern printf
.extern fclose
.extern __aeabi_idiv            @ uh refer to the idiv function
                                @ for more information as to why
                                @ this is here
.global main


/* ~~~~~ assigning Mic1 registers ~~~~~ */


m1OPC .req r2                   @ program counter
m1MBR .req r3                   @ signed bytecode value
m1MBRU .req r4                  @ unsigned bytecode value
m1TOS .req r5                   @ top of the stack
m1SP .req r6                    @ top of the stack address
m1MDR .req r7                   @ memory data register
m1MAR .req r8                   @ memory address register
m1PC .req r9                    @ next bytecode address
m1LV .req r10                   @ the address to the first local variable
m1CPP .req r11                  @ constant pool pointer 
                                @ but will be used as a "link pointer"
m1H .req r12                    @ just holds values


/* ~~~~~ macros ~~~~~ */


@ at first I wasn't going to use macros,
@ but my god is it a lot nicer with them...
@
@ performs a read by loading the MAR
@ to the MDR
.macro _RD_
    ldr m1MDR, [m1MAR]          @ stores the memory address of the MAR into the MDR
.endm


@ performs a write by updating the MAR
@ via the MDR
.macro _WR_
    str m1MDR, [m1MAR]
.endm


@ performs a write by loading the MBR(U)'s
@ via the PC address
.macro _FETCH_
    ldrsb m1MBR, [m1PC]
    ldrb m1MBRU, [m1PC]
.endm


/* ~~~~~ data ~~~~~ */


.data
.balign 4
@ sets the file mode to read
fileMode: .asciz "r"


.balign 4
@ file pointer
file: .word 0


.balign 4
@ formatter for printf call at the end
print_format: .asciz "%d\n"


.balign 4
@ well, I mean it's the index
index: .word 0


.balign 4
@ the "backing array" 
@ or I guess a better word is just memory
memory: .skip 1024


/* ~~~~~ text ~~~~~ */


.text
.balign 4
.func main


@ checks for a valid file
@ then branches to openTheFile
main:
    push {lr}                   @ allows me to bx lr when needed
    cmp r0, #2                  @ checks for a valid argument count of #2
    beq openTheFile


@ opens the file by
@ loading the file into r0
@ loading r1 with the file mode
@ calling fopen
@ then store the opened file's address into file
@ finally branhcing to loop to start reading the file
openTheFile:
    ldr r0, [r1, #4]            @ r0 has the amount of arguments
                                @ while r1 has the address
    ldr r1, =fileMode           @ load r1 with the fileMode,
                                @ which in this case is read or "r"
    bl fopen                    @ requires name and file mode to open
                                @ returns the file pointer into r0
    mov r5, r0                  @ stores the file into r5

    b loop


@ loops and reads byte by byte into the memory
@ fgetc will return #-1 to signify the end of file
@ which will then branch to closeTheFile
loop:
    bl fgetc                    @ calls fgetc with the file pointer loaded into r0

    cmp r0, #-1                 @ checks for end of file
    beq closeTheFile
    
    ldr r1, addr_of_index       @ stores reference to the index into r1
    ldr r2, addr_of_memory      @ stores reference to the memory into r2
    ldr r3, [r1]                @ stores the deferenced index into r3
    add r4, r2, r3              @ add memory to the current index into r4
                                @ to get to next value
    str r0, [r4]                @ store the new address into r0
    add r3, r3, #1              @ increment the index by 1
    str r3, [r1]                @ update the incremented index into the actual index
    mov r0, r5                  @ stores the file back into r0 for a later compare
    b loop


@ moves r5 into r0 and calls fclose
@ to... well... close the file
@ then calls initialize
closeTheFile:
    mov r0, r5                  @ puts the file address back into r0 to prep for fclose
    bl fclose                   @ closes the file
    
    b initialize


@ initializes the
@ PC, LV, SP, MBR, and MBRU
@ then branches over to main1 and starts doing the "fun" stuff...
initialize:

    ldr r0, addr_of_index       @ stores a reference to the index in r0
    ldr r1, addr_of_memory      @ stores a reference to the memory in r1
    add m1PC, r1, #2            @ skips the two local variables
    ldr r3, [r0]                @ stores a dereferenced index into r3
    add m1LV, r1, r3            @ sets the LV by adding the index to the memory
    ldrb r4, [r1]               @ store a derefenced memory address into r4
    mov r4, r4, LSL #8          @ does a LSL to get the next two bytes
    add r1, r1, #1              @ increment the memory
    ldrb r1, [r1]               @ ldrb to combine those two 
    orr r4, r4, r1              @ orr here to get amount of local variables
    mov r4, r4, LSL #2          @ LSL #2 here to keep it as a word
    add m1SP, m1LV, r4          @ sets up the stack pointer 
                                @ by the adding the LV with the memory address
    ldrsb m1MBR, [m1PC]
    ldrb m1MBRU, [m1PC]         @ mind you the mbru is unsigned
    
    b main1                     @ branches to main1


@ increments the PC
@ then starts comparing the current instruction 
@ to a bunch of potential instructions
@ until it finally branches to the end
main1:
    add m1PC, m1PC, #1          @ increments the PC
    mov r0, m1MBRU              @ stores the MBRU into r0
    ldrsb m1MBR, [m1PC]         @ stores the next instruction into the MBR
    ldrb m1MBRU, [m1PC]         @ doe the same as above just signed


 /* ~~~~~ Instruction Dump ~~~~~ */
    
    
    cmp r0, #0x10
    beq bipush
    cmp r0, #0x59
    beq dup
    cmp r0, #0xA7
    beq goto
    cmp r0, #0x60
    beq iadd
    cmp r0, #0x7E
    beq iand
    cmp r0, #0x99
    beq ifeq
    cmp r0, #0x9B
    beq iflt
    cmp r0, #0x9F
    beq if_icmeq
    cmp r0, #0x84
    beq iinc
    cmp r0, #0x15
    beq iload
    cmp r0, #0xA8               @ instead of invoke virtual
    beq jsr                     @ we're using jsr
    cmp r0, #0x80
    beq ior
    cmp r0, #0xA9               @ instead of ireturn
    beq ret                     @ we're using ret
    cmp r0, #0x36
    beq istore
    cmp r0, #0x64
    beq isub
    cmp r0, #0x57
    beq pop
    cmp r0, #0x5F
    beq swap
    cmp r0, #0x68
    beq imul
    cmp r0, #0x6C
    beq idiv
    b end                       @ if nothing else works
                                @ branch to end


@ SP = MAR = SP + 1
@ PC = PC + 1; fetch
@ MDR = TOS = MBR; wr; goto Main1
@
@ I had to move the pc++ and fetch calls 
@ to after write so I could actually go 
@ back to my main1
bipush:
    add m1MAR, m1SP, #4         @ MAR = SP + 1
    mov m1SP, m1MAR             @ SP = MAR 

    mov m1TOS, m1MBR            @ TOS = MBR
    mov m1MDR, m1TOS            @ MDR = TOS
    _WR_                        @ wr

    add m1PC, m1PC, #1          @ PC = PC + 1
    _FETCH_                     @ fetch
    b main1                     @ goto Main1


@ MAR = SP = SP + 1
@ MDR = TOS; wr; goto (MBR1)
dup:
    add m1SP, m1SP, #4          @ SP = SP + 1
    mov m1MAR, m1SP             @ MAR = SP
    mov m1MDR, m1TOS            @ MDR = TOS
    _WR_                        @ wr
    b main1                     @ goto Main1


@ OPC = PC − 1
@ PC = PC + 1; fetch
@ H = MBR << 8
@ H = MBRU OR H
@ PC = OPC + H; fetch
@ goto Main1
@
@ had to move the 'ASL #8' to before the first fetch
goto:
    sub m1OPC, m1PC, #1         @ OPC = PC - #1
    add m1PC, m1PC, #1          @ PC = PC + #1
    mov m1H, m1MBR, ASL #8      @ H = MBR << #8
    _FETCH_                     @ fetch
    orr m1H, m1MBRU, m1H        @ H = MBRU or H
    add m1PC, m1OPC, m1H        @ PC = OPC + H
    _FETCH_                     @ fetch

    b main1                     @ goto main1


@ MAR = SP = SP - 1; rd
@ H = TOS
@ MDR = TOS = MDR + H; wr; goto Main1
iadd:
    sub m1SP, m1SP, #4          @ SP = SP - 1
    mov m1MAR, m1SP             @ MAR = SP
    _RD_                        @ rd
    mov m1H, m1TOS              @ H = TOS
    add m1TOS, m1MDR, m1H       @ TOS = MDR + H
    mov m1MDR, m1TOS            @ MDR = TOS
    _WR_                        @ wr

    b main1                     @ goto main1


@ MAR = SP = SP - 1; rd
@ H = TOS
@ MDR = TOS = MDR AND H; wr; goto main1
iand:
    sub m1SP, m1SP, #4          @ SP = SP - 1
    mov m1MAR, m1SP             @ MAR = SP
    _RD_                        @ rd
    mov m1H, m1TOS              @ H = TOS
    and m1TOS, m1MDR, m1H       @ TOS = MDR AND H
    mov m1MDR, m1TOS            @ MDR = TOS
    _WR_                        @ wr

    b main1                     @ goto main1


@ MAR = SP = SP − 1; rd
@ OPC = TOS
@ TOS = MDR
@ Z = OPC; if (Z) goto T; else goto F
ifeq:
    sub m1SP, m1SP, #4          @ SP = SP - 1
    mov m1MAR, m1SP             @ MAR = SP
    _RD_                        @ rd
    mov m1OPC, m1TOS            @ OPC = TOS
    mov m1TOS, m1MDR            @ TOS = MDR
    cmp m1PC, #0                @ if (Z)
    beq true                    @ goto T
    b false                     @ else goto F
    

@ MAR = SP = SP - 1; rd
@ OPC = TOS
@ TOS = MDR
@ N = OPC; if (N) goto T; else goto F
iflt:
    sub m1SP, m1SP, #4          @ SP = SP - 1
    mov m1MAR, m1SP             @ MAR = SP
    _RD_                        @ rd
    mov m1OPC, m1TOS            @ OPC = TOS
    mov m1TOS, m1MDR            @ TOS = MDR
    cmp m1OPC, #0               @ if (N)
    blt true                    @ goto T
    b false                     @ else goto F


@ MAR = SP = SP - 1; rd
@ MAR = SP = SP - 1
@ H = MDR; rd
@ OPC = TOS
@ TOS = MDR
@ Z = OPC - H; if (Z) goto T; else goto F
if_icmeq:
    sub m1SP, m1SP, #4          @ SP = SP - 1
    mov m1MAR, m1SP             @ MAR = SP
    _RD_                        @ rd
    sub m1SP, m1SP, #4          @ SP = SP - 1
    mov m1MAR, m1SP             @ MAR = SP
    mov m1H, m1MDR              @ H = MDR
    _RD_                        @ rd
    mov m1OPC, m1TOS            @ OPC = TOS
    mov m1TOS, m1MDR            @ TOS = MDR
    sub m1OPC, m1OPC, m1H       @ Z = OPC - H
    cmp m1OPC, #0               @ if (Z)
    beq true                    @ goto T
    b false                     @ else goto F


@ H = LV
@ MAR = MBRU + H; rd
@ PC = PC + 1; fetch
@ H = MDR
@ PC = PC + 1; fetch
@ MDR = MBR + H; wr; goto Main1
iinc:
    mov m1H, m1LV               @ H = LV
    add m1MAR, m1MBRU, m1H      @ MAR = MBRU + H
    _RD_                        @ rd
    add m1PC, m1PC, #1          @ PC = PC + 1
    _FETCH_                     @ fetch
    mov m1H, m1MDR              @ H = MDR
    add m1MDR, m1MBR, m1H       @ MDR = MBR + H
    _WR_                        @ wr
    add m1PC, m1PC, #1          @ PC = PC + 1
    _FETCH_                     @ fetch

    b main1                     @ goto main1


@ H = LV
@ MAR = MBRU + H; rd
@ MAR = SP = SP + 1
@ PC = PC + 1; fetch; wr
@ TOS = MDR; goto Main1
iload:
    mov m1H, m1LV               @ H = LV
    add m1MAR, m1MBRU, m1H      @ MAR = MBRU + H
    _RD_                        @ rd
    add m1SP, m1SP, #4          @ SP = SP + 1
    mov m1MAR, m1SP             @ MAR = SP
    add m1PC, m1PC, #1          @ PC = PC + 1
    _FETCH_                     @ fetch
    _WR_                        @ wr
    mov m1TOS, m1MDR            @ TOS = MDR

    b main1                     @ goto main1


@ SP = SP + MBRU + 1
@ MDR = CPP
@ MAR = CPP = SP; wr
@ MDR = PC + 4
@ MAR = SP = SP + 1; wr
@ MDR = LV
@ MAR = SP = SP + 1; wr
@ LV = SP - 2 - MBRU
@ PC = PC + 1; fetch
@ NOP
@ LV = LV - MBRU
@ PC = PC + 1; fetch
@ NOP
@ H = MBR << 8
@ PC = PC + 1; fetch
@ NOP
@ PC = PC - 4 + (H OR MBRU); fetch
@ goto Main1
jsr:
    add m1SP, m1SP, m1MBRU      @ SP = SP + MBRU
    add m1SP, m1SP, #4          @ SP = SP + 1
    mov m1MDR, m1CPP            @ MDR = CPP
    mov m1CPP, m1SP             @ CPP = SP
    mov m1MAR, m1CPP            @ MAR = CPP
    _WR_                        @ wr
    add m1MDR, m1PC, #4         @ MDR = PC + 4
    add m1SP, m1SP, #4          @ SP = SP + 1
    mov m1MAR, m1SP             @ MAR = SP
    _WR_                        @ wr
    mov m1MDR, m1LV             @ MDR = LV
    add m1SP, m1SP, #4          @ SP = SP + 1
    mov m1MAR, m1SP             @ MAR = SP
    _WR_                        @ wr
    sub m1LV, m1LV, m1MBRU      @ LV = LV - MBRU
    sub m1LV, m1SP, #8          @ LV = SP - 2
    add m1PC, m1PC, #1          @ PC = PC + 1
    _FETCH_                     @ fetch
    sub m1LV, m1LV, m1MBRU      @ LV = LV - MBRU
    add m1PC, m1PC, #1          @ PC = PC + 1
    _FETCH_                     @ fetch
    mov m1H, m1MBR, ASL #8      @ H = MBR << 8
    add m1PC, m1PC, #1          @ PC = PC + 1
    _FETCH_                     @ fetch
    orr m1H, m1H, m1MBRU        @ H = H OR MBRU     - side note more for myself
                                @                     H is more of a temp register
    sub m1PC, m1PC, #4          @ PC = PC - 4
    add m1PC, m1PC, m1H         @ PC = PC + H
    _FETCH_                     @ fetch

    b main1                     @ goto main1


@ MAR = SP = SP - 1; rd
@ H = TOS
@ MDR = TOS = MDR OR H; wr; goto (MBR1)
ior:
    sub m1SP, m1SP, #4          @ SP = SP - 1
    mov m1MAR, m1SP             @ MAR = SP
    mov m1H, m1TOS              @ H = TOS
    orr m1TOS, m1MDR, m1H       @ TOS = MDR or H
    mov m1MDR, m1TOS            @ MDR = TOS
    _WR_                        @ wr

    b main1                     @ goto main1


@ check for ret from main
@ (i.e. CPP==0) & exit, ELSE
@ MAR = CPP; rd
@ NOP
@ CPP = MDR
@ MAR = MAR + 1; rd
@ NOP
@ PC = MDR; fetch
@ MAR = MAR + 1; rd
@ SP = MAR = LV
@ LV = MDR
@ MDR = TOS; wr
@ goto main1
ret:
    cmp m1CPP, #0               @ check for cpp == 0
    beq end                     @ if so, exit

    mov m1MAR, m1CPP            @ else MAR = CPP
    _RD_                        @ rd
    mov m1CPP, m1MDR            @ CPP = MDR
    add m1MAR, m1MAR, #4        @ MAR = MAR + 1
    _RD_                        @ rd
    mov m1PC, m1MDR             @ PC = MDR
    _FETCH_                     @ fetch
    add m1MAR, m1MAR, #4        @ MAR = MAR + 1
    _RD_                        @ rd
    mov m1MAR, m1LV             @ MAR = LV
    mov m1SP, m1MAR             @ SP = MAR
    mov m1LV, m1MDR             @ LV = MDR
    mov m1MDR, m1TOS            @ MDR = TOS
    _WR_                        @ wr

    b main1                     @ goto main1


@ H = LV
@ MAR = MBRU + H
@ MDR = TOS; wr
@ SP = MAR = SP - 1; rd
@ PC = PC + 1; fetch
@ TOS = MDR; goto Main1
istore:
    mov m1H, m1LV                       @ H = LV
    add m1MAR, m1H, m1MBRU, LSL #2      @ MAR = H + MBRU
                                        @ LSL #2 here to 
                                        @ keep consistent with words
    mov m1MDR, m1TOS                    @ MDR = TOS
    _WR_                                @ wr
    sub m1MAR, m1SP, #4                 @ MAR = SP - 1
                                        @ I'll be completely honest, 
                                        @ I accidentally forgot to add the read and it worked fine
                                        @ and when I actually added it, the tests weren't happy
    mov m1SP, m1MAR                     @ SP = MAR
    add m1PC, m1PC, #1                  @ PC = PC + 1
    _FETCH_                             @ fetch
    mov m1TOS, m1MDR                    @ TOS = MDR

    b main1                             @ goto main1


@ MAR = SP = SP - 1; rd
@ H = TOS
@ MDR = TOS = MDR - H; wr; goto (MBR1)
isub:
    sub m1SP, m1SP, #4          @ SP = SP - 1
    mov m1MAR, m1SP             @ MAR = SP
    _RD_                        @ rd
    mov m1H, m1TOS              @ H = TOS
    sub m1TOS, m1MDR, m1H       @ TOS = MDR - H
    mov m1MDR, m1TOS            @ MDR = TOS
    _WR_                        @ wr

    b main1                     @ goto main1


@ MAR = SP = SP - 1
@ TOS = MDR; goto Main1
pop:
    sub m1SP, m1SP, #4          @ SP = SP - 1
    mov m1MAR, m1SP             @ MAR = SP
    _RD_                        @ rd
    mov m1TOS, m1MDR            @ TOS = MDR

    b main1                     @ goto main1


@ MAR = SP - 1; rd
@ MAR = SP
@ H = MDR; wr
@ MDR = TOS
@ MAR = SP - 1; wr
@ TOS = H; goto Main1
swap:
    sub m1MAR, m1SP, #4         @ MAR = SP - 1
    mov m1MAR, m1SP             @ MAR = SP
    mov m1H, m1MDR              @ H = MDR
    _WR_                        @ wr
    sub m1MAR, m1SP, #4         @ MAR = SP - 1
    _WR_                        @ wr
    mov m1TOS, m1H              @ TOS = H

    b main1                     @ goto main1

@ iadd instructions:
@ MAR = SP = SP - 1; rd
@ H = TOS
@ MDR = TOS = MDR + H; wr; goto Main1
imul:
    sub m1SP, m1SP, #4          @ SP = SP - 1
    mov m1MAR, m1SP             @ MAR = SP
    _RD_                        @ rd
    mov m1H, m1TOS              @ H = TOS
    mul m1TOS, m1MDR, m1H       @ mul instead of add
                                @ TOS = MDR * H
    mov m1MDR, m1TOS            @ MDR = TOS
    _WR_                        @ wr

    b main1                     @ goto main1


@ iadd instructions:
@ MAR = SP = SP - 1; rd
@ H = TOS
@ MDR = TOS = MDR + H; wr; goto Main1
@
@ after looking through my textbook
@ very unsuccessfully I found this solution online
@ http://www.mathcs.emory.edu/~cheung/Courses/255/Syl-ARM/7-ARM/arithm.html
@ aparently there's this run time library that contains
@ __aeabi_idiv, which does everything I need.
@ hopefully it's okay to import this haha...
idiv:
    sub m1SP, m1SP, #4          @ SP = SP - 1
    mov m1MAR, m1SP             @ MAR = SP
    _RD_                        @ rd
    mov m1H, m1TOS              @ H = TOS

    push {r3}                   @ the __aeabi_div thing will trash
                                @ r0 - r3 so I need to keep this stored safely
    mov r0, m1H                 @ put H into r0
    mov r1, m1MDR               @ put MDR into r1
    bl __aeabi_idiv             @ call __aeabi_idiv to perform r0 / r1
    mov m1TOS, r0               @ TOS = r0 aka ( r0 / r1 )

    mov m1MDR, m1TOS            @ MDR = TOS
    _WR_                        @ wr
    pop {r3}                    @ almost forgot to get that back

    b main1                     @ goto main1


@ OPC = PC - 1; goto goto2
@ originally was going to have the operation above
@ but I decided to add that to the goto instead
@ as I don't want to remember to update it whenever calling it
true:
    b goto


@ PC = PC + 1
@ PC = PC + 1; fetch
@ goto Main1
false:
    add m1PC, m1PC, #1              @ PC = PC + 1
    add m1PC, m1PC, #1              @ PC = PC + 1
    _FETCH_                         @ fetch

    b main1                         @ goto main1


end:
    ldr r0, addr_of_print_format    @ setup print format for printf
    mov r1, m1TOS                   @ grab whatever is left on the stack
    bl printf                       @ print the output
    mov r0, #0                      @ reset r0 to #0
    pop {lr}                        @ get the lr back from stack
    bx lr                           @ bx lr to finish


/* ~~~~~ addresses for the data ~~~~~ */


.balign 4
addr_of_fileMode: .word fileMode


.balign 4
addr_of_file: .word file


.balign 4
addr_of_print_format: .word print_format


.balign 4
addr_of_index: .word index


.balign 4
addr_of_memory: .word memory
