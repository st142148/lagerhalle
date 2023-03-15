package main

import "core:fmt"
import "core:runtime"
import "core:os"
import "core:strings"

int :: i32;

INTRINSICS := []string{"int", "rune", "enum", "struct", "map", "proc", "if", "else", "return", "for", "len", "import", "println", "exit", "main"};

source      : []int;   //source code
token       : int;     //current token
src, old_src: int;      //index into source code string
poolsize    : int;     //default size for text/data/stack
line        : int;      //line number

Token :: enum int {
    Num = 128, Fun, Sys, Glo, Loc, Id, Def, Decl,
    Rune, Else, Enum, If, Int, Return, Sizeof, While,
    Assign, Cond, Lor, Lan, Or, Xor, And, Eq, Ne, Lt, Gt, Le, Ge, Shl, Shr, Add, Sub, Mul, MulAss, Div, DivAss, Mod, Inc, Dec, Brak
};

Types :: enum int { RUNE, INT};
idmain :: int;      // the main procedure

basetype, expr_type : int;

Identifier :: struct {
    token   : int,
    hash    : int,
    name    : []int,
    class   : int,
    typ     : int,
    value   : int,
    Bclass  : int,
    Btyp    : int,
    Bvalue  : int,
}

token_val : int;
symbols : map[int]Identifier;

mem     : []int;       //main memory block
text    : []int;       //slice of mem
old_text: []int;       // - || -
stack   : []int;       // - || -
data    : []int;       // - || -

dp : int; //data pointer
pc, bp, sp, ax, cycle : int;

Inst :: enum int {
    LEA,  IMM,  JMP,  CALL, JZ,   JNZ,  ENT,  ADJ, LEV, LI,  LC,  SI,  SC,  PUSH,
    OR,   XOR,  AND,  EQ,   NE,   LT,   GT,   LE,  GE,  SHL, SHR, ADD, SUB, MUL, DIV, MOD,
    OPEN, READ, CLOS, PRTF, MALC, MSET, MCMP, EXIT
};

next :: proc() {
    using Token;
    last_pos : int;
    hash : int;
    for token = source[src]; token != 0; src += 1 {
        switch token {
            case '\n': ;
            case 'a'..'z', 'A'..'Z', '_', '\U000000C0'..'\UFFFFFFFF': 
                                //parse Identifier
                                last_pos = src - 1;
                                hash = token;
                                for source[src] >= '\U000000C0' || source[src] >= 'a' && source[src] <= 'Z' || source[src] >= 'a' && source[src] <= 'z' || source[src] >= '0' && source[src] <= '9' || source[src] == '_' {
                                    hash = hash * 147 + source[src];
                                    src += 1;
                                }
                                if token, ok := symbols[hash]; ok do return;
                                symbols[hash] = Identifier {name = source[last_pos:src-1], hash = hash, token = int(Id)};
                                token = int(Id);

            case '0'..'9':      //parse number: dec, hex or oct
                                token_val = token - '0';
                                if token_val > 0 {
                                    for source[src] >= '0' && source[src] <= '9' {
                                        token_val = token_val * 10 + source[src] - '0';
                                        src += 1;
                                    }
                                } else {
                                    if source[src] == 'x' || source[src] == 'X' {
                                        //hex
                                        src += 1; token = source[src];
                                        for (token >= '0' && token <= '9') || (token >= 'a' && token <= 'f') || (token >= 'A' && token <= 'F') {
                                            token_val = token_val * 16 + (token & 15) + (token >= 'A' ? 9 : 0);
                                            src += 1; token = source[src];
                                        }
                                    } else {
                                        for source[src] >= '0' && source[src] <= '7' {
                                            token_val = token_val * 8 + source[src] - '0';
                                            src += 1;
                                        }
                                    }
                                }
                                token = int(Num);
                                return;

            case '"', '\'':     // parse string literal, store it in "data"
                                last_pos = dp;
                                for source[src] != 0 && source[src] != token {
                                    token_val = source[src]; src += 1;
                                    if token_val == '\\' {
                                        //escape characters
                                        token_val = source[src]; src += 1;
                                        if token_val == 'n' do token_val = '\n';
                                    }
                                    if token == '"' {
                                        data[dp] = token_val;
                                        dp += 1;
                                    } 
                                }
                                src += 1;
                                //if single character, return Num token
                                if token == '"' do token_val = last_pos;
                                else do token = int(Num);
                                return;

            case '/':           //skip comments
                                if source[src] == '/' {
                                    for (source[src] != 0 && source[src] != '\n') do src += 1;
                                } else {
                                    token = int(Div);
                                    return;
                                }

            case ':':   if source[src] == '=' {
                            src += 1; token = int(Decl);
                        } else if source[src] == ':' {
                            src += 1; token = int(Def);
                        } else do return;

            case '=':   if source[src] == '=' {
                            src += 1; token = int(Eq);
                        } else do token = int(Assign);
            case '+':   if source[src] == '=' {
                            src += 1; token = int(Inc);
                        } else do token = int(Add);
            case '-':   if source[src] == '=' {
                            src += 1; token = int(Dec);
                        } else do token = int(Sub);
            case '!':   if source[src] == '=' {
                            src += 1; token = int(Ne);
                        } //else do token = int(Assign);
            case '<':   if source[src] == '<' {
                            src += 1; token = int(Shl);
                        } else if source[src] == '=' {
                            src += 1; token = int(Le);
                        } else do token = int(Lt);
            case '>':   if source[src] == '>' {
                            src += 1; token = int(Shr);
                        } else if source[src] == '=' {
                            src += 1; token = int(Ge);
                        }else do token = int(Gt);
            case '|':   if source[src] == '|' {
                            src += 1; token = int(Lor);
                        } else do token = int(Or);
            case '&':   if source[src] == '&' {
                            src += 1; token = int(Lan);
                        } else do token = int(And);
            case '~':   token = int(Xor);
            case '%':   token = int(Mod);
            case '*':   if source[src] == '=' {
                            src += 1; token = int(MulAss);
                        } else do token = int(Mul);
            case '[':   if source[src] == '=' {
                            src += 1; token = int(DivAss);
                        } else do token = int(Div);
            case '?':   token = int(Cond);
            case '{', '}', '(', ')', ']', ',': {
                            return;
                        }
        }
    }
}

expression :: proc(level : int) {
    token = source[src];
    src += 1;
}

match :: proc(tk: int) {
    if token == tk do next();
    else {
        fmt.println(line, ": expected token: ", tk);
        os.exit(-1);
    }
}

program :: proc() {
    next();
    for token > 0 {
        global_declaration();
    }
}

global_declaration :: proc() {
    // global_declaration ::= enum_decl | struct_decl | variable_decl | function_decl | alias_decl
    //
    // enum_decl ::= id '::' 'enum' '{' id ['=' num] {',' id ['=' num]} '}' ';'
    //
    // variable_decl ::= id { ',' id } ':' [ {'^'} type] ['=' num] ';'
    //
    // function_decl ::= id '::' 'proc' '(' parameter_decl ')' ['->' type] '{' body_decl '}'

    typ, i : int;
    basetype = int(Types.INT);

    match(token);
}

eval :: proc() -> int {
    op : Inst;
    tmp : int;
    for (true) {
        cycle += 1;
        op = Inst(text[pc]); pc += 1;
        fmt.println(op, " pc: ", int(pc), " sp: ", int(sp), " ax: ", int(ax), " bp: ", int(bp));
        switch op {
            case .IMM:      ax = text[pc];                      //load immediate value
                            pc += 1;

            case .LC:       ax = mem[ax];                       //load into ax
            case .SC:       data[sp] = ax;                      //store from ax
                            ax += 1;

            case .PUSH:     sp -= 1; stack[sp] = ax;                     //push to stack from ax
                            
            case .JMP:      pc = text[pc];                      
            case .JZ:       pc = ax == 0 ? pc + 1 : text[pc];
            case .JNZ:      pc = ax != 0 ? pc + 1 : text[pc];
            case .CALL:     sp -= 1; stack[sp] = pc + 1;        //store current execution position
                            pc = text[pc];                      //jump to routine
            //case .RET:      pc = stack[sp];
            //                sp += 1;

            case .ENT:      sp -= 1; stack[sp] = bp;            //make new calling frame
                            sp -= text[pc]; pc += 1;

            case .ADJ:      sp += text[pc]; pc += 1;            //adjust stack size
            case .LEV:      sp = bp;                            //restore call frame and PC
                            bp = stack[sp]; sp += 1;
                            pc = stack[sp]; sp += 1;

            case .LEA:      ax = stack[bp + text[pc]]; pc += 1; //load address for arguments
            //MATH
            case .OR:       ax = stack[sp] | ax; sp += 1;
            case .XOR:      ax = stack[sp] ~ ax; sp += 1;
            case .AND:      ax = stack[sp] & ax; sp += 1;
            case .EQ:       ax = int(stack[sp] == ax); sp += 1;
            case .NE:       ax = int(stack[sp] != ax); sp += 1;
            case .LT:       ax = int(stack[sp] < ax); sp += 1;
            case .LE:       ax = int(stack[sp] <= ax); sp += 1;
            case .GT:       ax = int(stack[sp] > ax); sp += 1;
            case .GE:       ax = int(stack[sp] >= ax); sp += 1;
            case .SHL:      ax = stack[sp] << u32(ax); sp += 1;
            case .SHR:      ax = stack[sp] >> u32(ax); sp += 1;
            case .ADD:      ax = stack[sp] + ax; sp += 1;
            case .SUB:      ax = stack[sp] - ax; sp += 1;
            case .MUL:      ax = stack[sp] * ax; sp += 1;
            case .DIV:      ax = stack[sp] / ax; sp += 1;
            case .MOD:      ax = stack[sp] % ax; sp += 1;
            //INTRINSICS
            case .EXIT:     fmt.println(stack[sp]); return int(stack[sp]);
            //case .OPEN:
            //case .CLOS:
            //case .READ:
            case .PRTF:     tmp = sp + pc + 1;
                            ax = int(fmt.println(stack[sp-1], stack[sp-2], stack[sp-3], stack[sp-4], stack[sp-5], stack[sp-6]));

            case:           fmt.println("Unknown instruction: ", op, " Cycle: ", cycle);
                            return -1;
        }
    }
    return 0;
}

main :: proc() {
    args := runtime.args__;

    if (len(args)<2) {
        fmt.println("No source file specified!");
        return;
    }

    if src_file, ok := os.read_entire_file(string(args[1])); ok{
        source = make([]int, len(src_file));
        defer delete(source);
        for char, i in src_file {
            source[i] = int(char);
        }
        fmt.println("Source file loaded; ", len(src_file), " bytes");
    } else {
        fmt.println("Failed to read source file!");
        return;
    }

    using Types;
    using Token;

    symbols = make(map[int]Identifier);
    defer delete(symbols);

    for intr, j in INTRINSICS {
        hash : int = int(intr[0]);
        name_t := make([dynamic]int);
        for i in 1 .. len(intr) {
            hash = hash * 147 + int(intr[i]);
            append(&name_t, int(intr[i]));
        }
        symbols[hash] = Identifier{hash = hash, class = int(Sys), typ = int(INT), value = int(j)};
    }

    poolsize = 256 * 1024;
    line = 1;

    mem      = make([]int, poolsize * 4);
    text     = mem[            :poolsize - 1];
    old_text = mem[poolsize    :poolsize * 2 - 1];
    stack    = mem[poolsize * 2:poolsize * 3 - 1];
    data     = mem[poolsize * 3:poolsize * 4 -1];

    bp = poolsize - 1;
    sp = poolsize - 1;
    ax = 0;

    using Inst;
    text[0] = int(IMM);
    text[1] = 10;
    text[2] = int(PUSH);
    text[3] = int(IMM);
    text[4] = 20;
    text[5] = int(ADD);
    text[6] = int(PUSH);
    text[7] = int(EXIT);
    pc = 0;

    program();
    eval();
}