NAME=hello
rm -rf $NAME
mkdir $NAME
cd $NAME
git init

EMPTY_TREE=$(git write-tree)
QUIT=$(git commit-tree -m "quit" $EMPTY_TREE)
PUTCHAR=$(git commit-tree -m "putchar [print-loop]" $EMPTY_TREE)
PRINT_LOOP=$(git commit-tree -m "1 right read dup" -p $QUIT -p $PUTCHAR $EMPTY_TREE)
git tag print-loop $PRINT_LOOP

WRITE=$(git commit-tree -m "write 1 left [reverse-loop]" $EMPTY_TREE)
REVERSE_LOOP=$(git commit-tree -m "dup" -p $PRINT_LOOP -p $WRITE $EMPTY_TREE)
git tag reverse-loop $REVERSE_LOOP

INPUT=$(git commit-tree -m "\"Hello world\\n\"" -p $REVERSE_LOOP $EMPTY_TREE)
git reset $INPUT
