SCRIPTS := $(wildcard *.sh)
REPOS := $(patsubst %.sh, %, $(SCRIPTS))

all: $(REPOS)

%: %.sh
	sh $<

clean:
	rm -rf $(REPOS)
