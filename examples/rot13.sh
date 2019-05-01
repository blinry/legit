NAME=rot13
rm -rf $NAME
mkdir $NAME
cd $NAME
git init -q

EMPTY_TREE=$(git write-tree)

QUIT=$(git commit-tree -m "quit" $EMPTY_TREE)
PUTCHAR=$(git commit-tree -m "putchar [loop]" $EMPTY_TREE)
ADD=$(git commit-tree -m "13 add" -p $PUTCHAR $EMPTY_TREE)
SUB=$(git commit-tree -m "13 sub" -p $PUTCHAR $EMPTY_TREE)
OVER_z=$(git commit-tree -m "dup z cmp" -p $SUB -p $PUTCHAR $EMPTY_TREE)
OVER_m=$(git commit-tree -m "dup m cmp" -p $ADD -p $OVER_z $EMPTY_TREE)
OVER_BACKTICK=$(git commit-tree -m "dup a 1 sub cmp" -p $PUTCHAR -p $OVER_m $EMPTY_TREE)
OVER_Z=$(git commit-tree -m "dup Z cmp" -p $SUB -p $OVER_BACKTICK $EMPTY_TREE)
OVER_M=$(git commit-tree -m "dup M cmp" -p $ADD -p $OVER_Z $EMPTY_TREE)
OVER_AT=$(git commit-tree -m "dup A 1 sub cmp" -p $PUTCHAR -p $OVER_M $EMPTY_TREE)
GETCHAR=$(git commit-tree -m "getchar dup" -p $QUIT -p $OVER_AT $EMPTY_TREE)

git tag loop $GETCHAR
git reset $GETCHAR
