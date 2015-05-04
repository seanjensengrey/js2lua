local parse = {}

require 'lxsh'
local js = require 'js_lexer'
local util = require 'util'

local file = io.open(arg[1],"r")
local src = file:read("*a")
print(src)
io.close(file)

local cursor = 0
local current

--local generated_code = ""

local gen_table = {}
--local tree = {}

for kind, text, lnum, cnum in js.gmatch(src) do
	print(string.format('%s: %q (%i:%i)', kind, text, lnum, cnum))
	if kind ~= 'comment' and kind ~= 'whitespace' then
		table.insert(gen_table,{kind = kind, text = text, line = lnum, char = cnum})
	end
end

function parse.next()
	cursor = cursor+1
	current = gen_table[cursor]
	return current
end

function parse.showNext()
	return gen_table[cursor+1]
end

function parse.identList(n)
	n = n or 0
	local token = parse.showNext()
	if token.kind ~= 'rightpar' then
		n = n + 1
		parse.expect('identifier')
		token = parse.showNext()
		if token.kind == 'coma' then
			parse.next() -- accept
			parse.identList(n+1)
		end
	end
	return n
end

function parse.expect(tokenKind, msg)
	local token = parse.next()
	if not token then
		msg = (msg or '').."Parsing error. Missing '}'."
		error(msg)
	elseif token.kind ~= tokenKind then
		msg = (msg or '').."Parsing error on "..token.line..":"..token.char..". Expecting "..tokenKind.." but got "..token.kind.."."
		error(msg)
	end
	return token
end

function parse.call()
	print('Parsing Function Call')
	parse.expect('leftpar')
	parse.identList()
	parse.expect('rightpar')
end

local function auxExp()
	--while util.in_table({'+','-','*','/','%'},(parse.showNext()).text) do
	while (parse.showNext()).kind == 'operator' do
		parse.next()
		parse.expression()
	end
end

function parse.expression()
	print("Parsing Expression")
	local token = parse.showNext()
	if token.kind == 'number' then		-- NUMBER
		parse.next() -- accept
		auxExp()
	else
		parse.expect('identifier','Expression error. ') -- IDENTIFIER
		local token = parse.showNext()
		if token.kind == 'leftpar' then  -- FUNCTION CALL
			parse.call()
		else
			auxExp()					-- NORMAL VAR ACCESS
		end
	end	
end

function parse.declaration()
	print("Parsing Declaration")
	parse.expect('var')				-- var x =
	parse.expect('identifier')
	parse.expect('equal')
	local token = parse.showNext()
	if token.kind == 'function' then -- FUNCTION DECLARATION
		parse.next()
		parse.expect('leftpar')
		parse.identList()
		parse.expect('rightpar')
		parse.expect('leftcurly')
		parse.stmt()
		parse.expect('rightcurly')
	else
		parse.expression() -- NORMAL DECLARATION
	end
end

function parse.stIf()
	print("Parsing If")
	parse.expect('if')		-- if(exp){ stmt* }[else [stIf]* | {}]?
	parse.expect('leftpar')
	parse.expression()
	parse.expect('rightpar')
	parse.expect('leftcurly')
	parse.stmt()
	parse.expect('rightcurly')

	local token = parse.showNext()
	if token.kind == 'else' then
		parse.next()
		token = parse.showNext()
		if token.kind == 'if' then
			parse.stIf() -- will parse infinite else ifs :)
		else
			parse.expect('leftcurly')
			parse.stmt()
			parse.expect('rightcurly')
		end
	end
end

function parse.assign()
	print("Parsing Assignment") -- x = exp or x++
	
	local token = parse.showNext()
	if util.in_table({'=','+=','-=','*=','/=','%='},token.text) then 
		parse.next()
		parse.expression()

	elseif util.in_table({'++','--'},token.text) then
		parse.next()

	else
		error("Parsing error on "..token.line..":"..token.char..". Expected operator, got "..token.kind)
	end
end

function parse.stmt()
	print("Parsing Statement")
	local token = parse.showNext()
	-- DECLARATION
	if token.kind == 'var' then
		parse.declaration()
		parse.expect('semicolon')

	-- IF
	elseif token.kind == 'if' then
		parse.stIf()

	elseif token.kind == 'identifier' then
		parse.next() -- accept

		token = parse.showNext()

		-- FUNCTION CALL
		if token.kind == 'leftpar' then
			parse.call()
			parse.expect('semicolon')

		-- ASSIGNMENT
		else
			parse.assign()
			parse.expect('semicolon')
		end

	 -- TODO: while, for, etc
	elseif token.kind ~= 'rightcurly' then
		error("Parsing error on "..token.line..":"..token.char..". Expected ?, got "..token.kind)
	end

	if parse.showNext() and (parse.showNext()).kind ~= 'rightcurly' then
		parse.stmt()
	end
end


parse.stmt()
