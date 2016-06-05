require "kabali/version"
require "terminal-table"

module Kabali
  class MyBlock
    attr_accessor :title,:data
  end
  class Kabali
    attr_accessor :message,:stack,:blocks      # Members of the class
    
    # Constructor
    def initialize(message)
      final_yarv = []                      # This array would be used to store the final YARV code, stripped off all the additional info 
      obj_code = RubyVM::InstructionSequence.compile(message).disasm # Disassemble the object code
      lines = obj_code.split("\n")         # Split the lines in separate lines.
      
      # Sanity check
      """
      extract_blocks(lines).each do |e|
        puts e.title
        puts e.data
      end
      lines[1,lines.length].each do |line| # Skip the first line, and iterate through the other lines.
        final_yarv.push line[5,line.length]           # Skip the first column, which had 4 digit numbers
      end
      """
      # Sanity check end
      
      self.message = extract_blocks(lines)    # Store the final yarv in the member data. 
      self.stack = []                      # Initializing the stack
      self.blocks = []
    end  # End of method initialize 
    
    # This method extracts different blocks from the code
    def extract_blocks(lines)   
      extracted_blocks = []
      temp_block = []
      temp = nil
      lines.each do |o|
        if o.include? "disasm"
          if !temp.nil? 
            temp.data = temp_block
            extracted_blocks.push temp
          end
          temp = MyBlock.new    # Storing the data and title of the blocks in the programs
          temp_block = []
          split_value = o.split('@')[0].split(':')[-1]
          #if split_value == "<compiled>" # This is the code for the main block
          temp.title = split_value
          #else
          #  temp.title = split_value.split('in').first.strip # The other nested blocks are caught here
          #end
        else
          unless o.include? "catch" or o.include? "-----" # Ignoring the catch statements.
            temp_block.push o[5,o.length]
          end
        end
      end
      temp.data = temp_block
      extracted_blocks.push temp
      extracted_blocks
    end
    
    # Helper method to call lisp, to draw the stack
    def draw title,counter
      rows = []
      self.stack.each do |row|
        a = []
        a.push row
        rows << a
      end
      puts "Press enter for next -->"
      gets
      puts `clear`              # Clear screen before display
      self.message.each do |block|
        a = []
        count = 0
        block.data.each do |d|
          if block.title == title and count == counter # Check if this is the line being disassembled
              d = "*"+d                                # Add a * to the line that is being disas
              row= [d]
              a.push row
          else                  # Else handles the lines that are not being disas
            row = [d]
            a.push row
          end
          count = count+1
        end
        table_block = Terminal::Table.new :headings => [block.title],:rows => a # Table for the blocks
        puts table_block
      end
      table = Terminal::Table.new :headings => ["Stack"],:rows => rows.reverse # Table for stack
      puts table
    end  # End of method draw
    
    # Tracing through the YARV structure. This method will call the draw and resolve helpers.
    def traverse
      args = ""
      self.message.each do |m|
        if m.title == "<compiled>"
          args = m
          break
        end
      end
      counter = 0               # Counter for the line number
      args.data.each do |arg|
        resolve(arg,"<compiled>",counter)            # Resolve and call the argument
        counter = counter + 1
        # puts self.stack.inspect
      end                # End of block args
    end                  # End of method trace  
    
    # This method gets called for individual blocks, for times, etc. 
    def traverse_block name
      args = ""
      self.message.each do |m|
        if m.title == name
          args = m
          break
        end
      end
      counter = 0
      args.data.each do |arg|
        resolve(arg,args.title,counter)            # Resolve and call the argument
        counter = counter + 1
      end                 # End of block args
    end
    
    # Resolving YARV commands
    def resolve(args,title,counter)
      draw title,counter
      # puts self.stack.inspect
      opcode = args.split(' ')
      case opcode[0]
      
      when "trace"              # Ignore this, do something if you want.
      
      when "putself"            # Put the self object to stack
        stack.push "self"

      when "putiseq"
        self.blocks.push opcode[1]

      when /putobject.*/, "putstring","putspecialobject"        # Put the object to stack, sometimes the format is different
        if opcode[1]
          temp = ""
          opcode.each do |o|
            unless o == opcode[0]
              temp = temp+o+" "
            end
          end
          self.stack.push temp
        else
          self.stack.push opcode[0].split('_')[4]
        end
      
      when "opt_plus"           # Pop the two elements off stack, compute sum
        arg_1 = self.stack.pop
        arg_2 = self.stack.pop
        self.stack.push arg_1.to_i + arg_2.to_i
      
      when "opt_send_without_block", "opt_send_simple" # Sending without block, so it means we pop one off the stack and push the return value
        if self.blocks.include? opcode[1].split(":")[1].delete(',')
          traverse_block opcode[1].split(":")[1].delete(',')
        end
      
      when "send"
        self.stack.pop
        temp = args.split(',')[-1].strip.split(':')[1]
        traverse_block temp[0,temp.length-1]
       
      when "leave"              # Ignore this, do something if you want.
        self.stack.pop
      
      else
         puts opcode[0]
      end                       # Switch case ends
     end  # End of method resolve
    
    private :draw,:resolve      # These methods aren't meant to be accessible from outside
  end    # End of class 
end      # End of Module
