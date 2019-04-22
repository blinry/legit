# legit

Programs written in *legit* are defined entirely by the commits in a Git repository. The contents of the repository are ignored. Influences: [Befunge](https://esolangs.org/wiki/Befunge), [Brainfuck](https://esolangs.org/wiki/Brainfuck), [Folders](https://esolangs.org/wiki/Folders).

(This specification will probably not be stable for a while.)

## Memory

Two types of data structures are available: A stack, and an endless tape. Both hold signed integers.

## Execution

Execution starts at the commit pointed to by the master branch. Commit messages can contain a series of single-word instructions, seperated with spaces, which are executed one by one.

After executing a commit with a tag, jump to the branch with the same name (which can be optionally prefixed with "origin/"). Otherwise:

- If a commit has only one parent, execution will continue there after executing all instructions in the current commit.
- If a commit has multiple parents (numbered 1, 2, 3, ...), the top stack element will be popped. If that element is n, to go (n-1)-th parent, or to the last one, if there are less than (n-1) parents.

## Instructions

I/O:

- `getchar`: read char from STDIN and place it on the stack
- `putchar`: pop top stack element and write it to STDOUT as a char
- `<Number>`: push the number on the stack
- `<Letter>`: push ASCII value of that letter on the stack
- `"<Letters>"`: unescape string, then push the individual ASCII characters on the stack

Stack operations:

- `add`: pop two topmost stack values, add them, push result on the stack
- `sub`: pop two topmost stack values, subtract top one from bottom one, push result on the stack
- `dup`: duplicates topmost stack value
- `cmp`: pops two top values, pushes 1 if bottommost one is larger, 0 otherwise

Tape operations:

- `read`: place value of current cell on the stack
- `write`: pop top stack element and write it to the current cell
- `left`: pop top stack value, move left for that many places
- `right`: pop top stack value, move right for that many places

General:

- `quit`: stop the program

# Running the interpreter

You'll need Ruby, and the "rugged" Gem:

     gem install rugged

`legit` comes with some examples, which can unfortunately not be added to this repository, because the programs are Git repositories themselves. To get them, run:

    git submodule init
    git submodule update

Then, to execute a program, run

    ruby interpreter.rb examples/hello/

# Running the compiler

There's also a compiler, which compiles a *legit* program to [LLVM IR](https://llvm.org/docs/LangRef.html). You can then use LLVM tools to build binaries for all plaforms where you have a C standard library available (*legit* will be linked with `exit()`, `getchar()` and `putchar()`). Here's how to do it:

    ruby compiler.rb examples/hello/
    clang -O3 hello.ll -o hello

As an alternative to the second step, you can use the provided Makefile and simply run `make hello`.
