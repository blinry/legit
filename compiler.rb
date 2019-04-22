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

@stack = global [1000 x i8] zeroinitializer

; The stack pointer is an index into the stack.
@sp = global i64 zeroinitializer

define void @push(i8 %val) {
  %sp = load i64, i64* @sp
  %addr = getelementptr [1000 x i8], [1000 x i8]* @stack, i64 0, i64 %sp
  store i8 %val, i8* %addr

  %newsp = add i64 %sp, 1
  store i64 %newsp, i64* @sp

  ret void
}

define i8 @pop() {
    %sp = load i64, i64* @sp
    %newsp = sub i64 %sp, 1

    %addr = getelementptr [1000 x i8], [1000 x i8]* @stack, i64 0, i64 %newsp
    %val = load i8, i8* %addr

    store i64 %newsp, i64* @sp

    ret i8 %val
}

define i32 @main() {
HERE
        # It's not possible to jump to the first basic block of a function, so this
        # is a workaround to avoid having a label on the first line.
        ir << "  br label %commit#{commits.first.oid}\n"

        commits.each do |c|
            ir << "commit"+c.oid+":\n"

            u = c.oid[0..7]
            i = 0

            c.message.myshellsplit.each do |command|
                uu = u+i.to_s
                i += 1

                case command
                when "getchar"
                    ir << "  %c#{uu} = call i32 @getchar()\n"
                    ir << "  %c2#{uu} = trunc i32 %c#{uu} to i8\n"
                    ir << "  %c3#{uu} = icmp eq i8 %c2#{uu}, -1\n"
                    ir << "  %c4#{uu} = select i1 %c3#{uu}, i8 0, i8 %c2#{uu}\n"
                    ir << "  call void @push(i8 %c4#{uu})\n"
                when "putchar"
                    ir << "  %c#{uu} = call i8 @pop()\n"
                    ir << "  call void @putchar(i8 %c#{uu})\n"
                when "dup"
                    ir << "  %c#{uu} = call i8 @pop()\n"
                    ir << "  call void @push(i8 %c#{uu})\n"
                    ir << "  call void @push(i8 %c#{uu})\n"
                when "add"
                    ir << "  %a#{uu} = call i8 @pop()\n"
                    ir << "  %b#{uu} = call i8 @pop()\n"
                    ir << "  %c#{uu} = add i8 %a#{uu}, %b#{uu}\n"
                    ir << "  call void @push(i8 %c#{uu})\n"
                when "sub"
                    ir << "  %a#{uu} = call i8 @pop()\n"
                    ir << "  %b#{uu} = call i8 @pop()\n"
                    ir << "  %c#{uu} = sub i8 %b#{uu}, %a#{uu}\n"
                    ir << "  call void @push(i8 %c#{uu})\n"
                when "cmp"
                    ir << "  %a#{uu} = call i8 @pop()\n"
                    ir << "  %b#{uu} = call i8 @pop()\n"
                    ir << "  %c#{uu} = icmp ugt i8 %b#{uu}, %a#{uu}\n"
                    ir << "  %c2#{uu} = zext i1 %c#{uu} to i8\n"
                    ir << "  call void @push(i8 %c2#{uu})\n"
                    #when "read"
                    #  @stack.push @tape.read
                    #when "write"
                    #  @tape.write @stack.pop
                    #when "left"
                    #  v = @stack.pop
                    #  @tape.left v
                    #when "right"
                    #  v = @stack.pop
                    #  @tape.right v
                when "quit"
                    ir << "  call void @exit(i32 0)\n"
                when /\d+/
                    ir << "  call void @push(i8 #{command.to_i})\n"
                when /^[a-zA-Z]$/
                    ir << "  call void @push(i8 #{command[0].ord})\n"
                    #when /^".*"$/
                    #  command.undump.split("").each do |c|
                    #    @stack.push c.ord
                    #  end
                else
                    raise "Unknown command '"+command+"'"
                end
            end

            did_jump = false

            @repo.references.each("refs/tags/*") do |ref|
                if c == ref.target
                    tagname = ref.name.split("/").last
                    branch = @repo.branches[tagname] || @repo.branches["origin/"+tagname]
                    raise "Could not jump to branch '"+tagname+"'" unless branch
                    ir << "  br label %commit#{branch.target.oid}\n"
                    did_jump = true
                end
            end

            unless did_jump
                case c.parents.size
                when 0
                    ir << "  call void @exit(i32 0)\n"
                    ir << "  unreachable\n"
                when 1
                    ir << "  br label %commit#{c.parents.first.oid}\n"
                when 2
                    ir << "  %val#{u} = call i8 @pop()\n"
                    ir << "  %cmp#{u} = icmp eq i8 %val#{u}, 0\n"
                    ir << "  br i1 %cmp#{u}, label %commit#{c.parents[0].oid}, label %commit#{c.parents[1].oid}\n"
                else
                    raise "More than 2 parents are not implemented yet\n"
                end
            end
        end

        ir << "}\n"

        IO.write(outfile, ir)
    end
end

i = LegitCompiler.new(ARGV.first)
i.compile(File.basename(ARGV.first)+".ll")
