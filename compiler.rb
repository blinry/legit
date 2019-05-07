require "rugged"

class String
    def myshellsplit
        pieces = [""]
        stringmode = false
        self.strip.gsub(/\s+/, " ").split("").each do |c|
            if c == '"'
                stringmode = (not stringmode)
            elsif c == ' ' and not stringmode
                pieces << ""
            end

            unless c == ' ' and not stringmode
                pieces[-1] = pieces.last+c
            end
        end
        return pieces
    end
end

class LegitCompiler
    def initialize path
        @repo = Rugged::Repository.new(path)
        @debug = false
        @did_jump = false
    end

    def compile outfile
        commits = []
        queue = [@repo.branches["master"].target]
        until queue.empty?
            c = queue.shift
            commits << c
            c.parents.each do |parent|
                queue << parent unless commits.include? parent
            end
        end

        ir = <<HERE
declare void @exit(i32)
declare i32 @getchar()
declare void @putchar(i8)

@stack = global [10000 x i64] zeroinitializer
; The stack pointer is an index into the stack.
@sp = global i64 0

@tape = global [10000 x i64] zeroinitializer
; The tape pointer is an index into the tape.
@tp = global i64 5000

define void @push(i64 %val) {
  %sp = load i64, i64* @sp
  %addr = getelementptr [10000 x i64], [10000 x i64]* @stack, i64 0, i64 %sp
  store i64 %val, i64* %addr

  %newsp = add i64 %sp, 1
  store i64 %newsp, i64* @sp

  ret void
}

define i64 @pop() {
    %sp = load i64, i64* @sp
    %newsp = sub i64 %sp, 1

    %cmp = icmp eq i64 %newsp, -1
    br i1 %cmp, label %empty, label %continue

continue:
    %addr = getelementptr [10000 x i64], [10000 x i64]* @stack, i64 0, i64 %newsp
    %val = load i64, i64* %addr

    store i64 %newsp, i64* @sp

    ret i64 %val
empty:
    %newsp2 = add i64 %newsp, 1
    store i64 %newsp2, i64* @sp

    ret i64 0
}

define void @right(i64 %offset) {
    %tp = load i64, i64* @tp
    %newtp = add i64 %tp, %offset
    store i64 %newtp, i64* @tp

    ret void
}

define void @left(i64 %offset) {
    %tp = load i64, i64* @tp
    %newtp = sub i64 %tp, %offset
    store i64 %newtp, i64* @tp

    ret void
}

define i64 @read() {
  %tp = load i64, i64* @tp
  %addr = getelementptr [10000 x i64], [10000 x i64]* @tape, i64 0, i64 %tp
  %val = load i64, i64* %addr

  ret i64 %val
}

define void @write(i64 %val) {
  %tp = load i64, i64* @tp
  %addr = getelementptr [10000 x i64], [10000 x i64]* @tape, i64 0, i64 %tp
  store i64 %val, i64* %addr

  ret void
}

define i32 @main() {
HERE
        # It's not possible to jump to the first basic block of a function, so this
        # is a workaround to avoid having a label on the first line.
        ir << "  br label %commit#{commits.first.oid[0..7]}\n"

        commits.each do |c|
            ir << "commit"+c.oid[0..7]+":\n"

            u = c.oid[0..7]
            i = 0

            @did_jump = false

            c.message.myshellsplit.each do |command|
                uu = u+i.to_s
                i += 1

                case command
                when "get"
                    ir << "  %c#{uu} = call i32 @getchar()\n"
                    ir << "  %c2#{uu} = sext i32 %c#{uu} to i64\n"
                    ir << "  %c3#{uu} = icmp eq i64 %c2#{uu}, -1\n"
                    ir << "  %c4#{uu} = select i1 %c3#{uu}, i64 0, i64 %c2#{uu}\n"
                    ir << "  call void @push(i64 %c4#{uu})\n"
                when "put"
                    ir << "  %c#{uu} = call i64 @pop()\n"
                    ir << "  %c2#{uu} = trunc i64 %c#{uu} to i8\n"
                    ir << "  call void @putchar(i8 %c2#{uu})\n"
                when "dup"
                    ir << "  %c#{uu} = call i64 @pop()\n"
                    ir << "  call void @push(i64 %c#{uu})\n"
                    ir << "  call void @push(i64 %c#{uu})\n"
                when "pop"
                    ir << "  call i64 @pop()\n"
                when "add"
                    ir << "  %a#{uu} = call i64 @pop()\n"
                    ir << "  %b#{uu} = call i64 @pop()\n"
                    ir << "  %c#{uu} = add i64 %a#{uu}, %b#{uu}\n"
                    ir << "  call void @push(i64 %c#{uu})\n"
                when "sub"
                    ir << "  %a#{uu} = call i64 @pop()\n"
                    ir << "  %b#{uu} = call i64 @pop()\n"
                    ir << "  %c#{uu} = sub i64 %b#{uu}, %a#{uu}\n"
                    ir << "  call void @push(i64 %c#{uu})\n"
                when "cmp"
                    ir << "  %a#{uu} = call i64 @pop()\n"
                    ir << "  %b#{uu} = call i64 @pop()\n"
                    ir << "  %c#{uu} = icmp ugt i64 %b#{uu}, %a#{uu}\n"
                    ir << "  %c2#{uu} = zext i1 %c#{uu} to i64\n"
                    ir << "  call void @push(i64 %c2#{uu})\n"
                when "read"
                    ir << "  %a#{uu} = call i64 @read()\n"
                    ir << "  call void @push(i64 %a#{uu})\n"
                when "write"
                    ir << "  %a#{uu} = call i64 @pop()\n"
                    ir << "  call void @write(i64 %a#{uu})\n"
                when "right"
                    ir << "  %a#{uu} = call i64 @pop()\n"
                    ir << "  call void @right(i64 %a#{uu})\n"
                when "left"
                    ir << "  %a#{uu} = call i64 @pop()\n"
                    ir << "  call void @left(i64 %a#{uu})\n"
                when "quit"
                    ir << "  call void @exit(i32 0)\n"
                when /^\d+$/
                    ir << "  call void @push(i64 #{command.to_i})\n"
                when /^[a-zA-Z]$/
                    ir << "  call void @push(i64 #{command[0].ord})\n"
                when /^".*"$/
                    command.undump.split("").each do |c|
                        ir << "  call void @push(i64 #{c[0].ord})\n"
                    end
                when /^\[.*\]$/
                    tag_name = command[1..-2]
                    tag = @repo.tags[tag_name]
                    raise "Could not jump to tag '"+tagname+"'" unless tag
                    ir << "  br label %commit#{tag.target.oid[0..7]}\n"
                    @did_jump = true
                else
                    raise "Unknown command '"+command+"'"
                end
            end

            unless @did_jump
                case c.parents.size
                when 0
                    ir << "  call void @exit(i32 0)\n"
                    ir << "  unreachable\n"
                when 1
                    ir << "  br label %commit#{c.parents.last.oid[0..7]}\n"
                else
                    ir << "  %val#{u} = call i64 @pop()\n"
                    ir << "  switch i64 %val#{u}, label %commit#{c.parents.last.oid[0..7]} ["

                    c.parents[0..-2].each_with_index do |p, i|
                        ir << "i64 #{i}, label %commit#{p.oid[0..7]} "
                    end

                    ir << "]\n"
                end
            end
        end

        ir << "}\n"

        IO.write(outfile, ir)
    end
end

i = LegitCompiler.new(ARGV.first)
i.compile(File.basename(ARGV.first)+".ll")
