{
  function unroll(head, tail, idx) {
    if (idx == null) idx = -1;
    return [head].concat(tail.map(function(el) {
      return el[idx < 0 ? el.length + idx : idx];
    }));
  }

  function ast(node) {
    if (options.location) {
      node.location = location();
    }
    return node;
  }
}

Tiny
  = _ ProgramKeyword _ name:Identifier _ ':'
  _ declarations:Declarations
  _ body:BlockStatement
  _ endName:Identifier _ '.' _
  {
    if (name.name !== endName.name) {
      error('name at start and end of program should match');
    }
    return ast({type: 'Tiny', name, declarations, body});
  }

Declarations
  = declarations:(VarKeyword _ dec:Declaration* _ ';' { return dec; })?
  {
    return declarations || [];
  }

Declaration = ids:DeclarationNames _ ':' _ type:Type {
  return ast({
    type: 'Declaration',
    ids,
    valueType: type
  });
}
DeclarationNames
  =
  names:(
    head:Identifier tail:(_ ',' _ Identifier)*
    { return unroll(head, tail); }
  )? { return names || []; }

Type
  = IntegerKeyword
  / BooleanKeyword

Statement
 = AssignmentStatement
 / OutputStatement
 / IfStatement
 / WhileStatement
 / BlockStatement
 / ('' { return null; })

AssignmentStatement = left:Identifier _ AssignmentOperator _ right:Expression {
  return ast({type: 'AssignmentStatement', left, right});
}

OutputStatement = OutputKeyword _ '(' _ value:Expression _ ')' {
  return ast({type: 'OutputStatement', value});
}

IfStatement
  = IfKeyword _ test:Expression
  _ ThenKeyword _ consequent:Statement
  _ ElseKeyword _ alternate:Statement
  {
    return ast({type: 'IfStatement', test, consequent, alternate});
  }

WhileStatement = WhileKeyword _ test:Expression _ DoKeyword _ body:Statement {
  return ast({type: 'WhileStatement', test, body});
}

BlockStatement
  = BeginKeyword _ statements:(
    head:Statement tail:(_ ';' _ Statement)*
    { return unroll(head, tail); }
  )? _ EndKeyword
  {
    return ast({
      type: 'BlockStatement',
      body: (statements || []).filter(function(stmt) {
        // remove empty statements
        return stmt !== null;
      }),
    });
  }

Expression
  = BinaryExpression
  / PrimaryExpression

// prevents left-recursion for BinaryExpression
PrimaryExpression
  = Identifier
  / Literal
  / UnaryExpression
  / ReadKeyword { return ast({type: 'ReadExpression'}); }
  / '(' _ sub:Expression _ ')' { return sub; }

UnaryExpression = operator:'-' _ argument:Expression {
  return ast({type: 'UnaryExpression', operator, argument});
}

BinaryExpression
  = left:PrimaryExpression _ operator:BinaryOperator _ right:Expression
  {
    return ast({type: 'BinaryExpression', operator, left, right});
  }

BinaryOperator
  = '+'
  / LeqOperator

// HACK: The tws-based version of tiny uses flex and yacc, which gives separate
// lexing and tree-building steps. PEG does this all-in-one. It's useful to be
// able to get at the token list when comparing these parsers, so this lets us
// do that.
TokenList = _ list:(token:Token _ { return token; })* { return list; }

Whitespace 'whitespace'
  = $[ \t\v\f\r\n]+

// mandatory whitespace
__
  = Whitespace? Comment _
  / Whitespace
// optional whitespace
_ = __?

// TODO: consider counting comments in the token list
Token
  = Keyword
  / Operator
  / Identifier
  / Literal
  / Punctuation

Keyword
  = ProgramKeyword
  / VarKeyword
  / IntegerKeyword
  / BooleanKeyword
  / BeginKeyword
  / EndKeyword
  / OutputKeyword
  / IfKeyword
  / ThenKeyword
  / ElseKeyword
  / WhileKeyword
  / DoKeyword
  / ReadKeyword

ProgramKeyword =    $('program' !IdentifierPart)
VarKeyword =        $('var'     !IdentifierPart)
IntegerKeyword =    $('integer' !IdentifierPart)
BooleanKeyword =    $('boolean' !IdentifierPart)
BeginKeyword =      $('begin'   !IdentifierPart)
EndKeyword =        $('end'     !IdentifierPart)
OutputKeyword =     $('output'  !IdentifierPart)
IfKeyword =         $('if'      !IdentifierPart)
ThenKeyword =       $('then'    !IdentifierPart)
ElseKeyword =       $('else'    !IdentifierPart)
WhileKeyword =      $('while'   !IdentifierPart)
DoKeyword =         $('do'      !IdentifierPart)
ReadKeyword =       $('read'    !IdentifierPart)

Operator
  = AssignmentOperator
  / LeqOperator

AssignmentOperator = ':='
LeqOperator = '<='

// NOTE: In this implementation, identifiers can't be keywords to maintain full
// compatibility with the TWS. However, in cases where the grammar is not
// ambiguous, it should be possible to allow reserved names as identifier names.
// As a future feature, we could remove `!Keyword` to allow this.
Identifier 'identifier' = !Keyword name:$([_a-z]i IdentifierPart*) {
  return ast({type: 'Identifier', name});
}

// flex finds the longest possible match, which solves the ambiguity of an
// identifier following a keyword with no space nicely (the identifier match is
// longer and therefore chosen).
//
// PEG doesn't do that. Instead, we need to mark the identifiers as not ending
// in an IdentifierPart. An IdentifierPart represents the possible trailing
// characters of an identifier name, though the leading character may be more
// restricted.
IdentifierPart = [_a-z0-9]i

Literal
  = StringLiteral
  / IntegerLiteral

// TODO: for strict compatibility this disallows empty strings, but the grammar
// should really support it
StringLiteral = match:("'" value:$[^']+ "'" / '"' value:$[^"]+ '"') {
  return ast({
    type: 'Literal',
    valueType: 'string',
    value: match[0].value,
  });
}

IntegerLiteral = match:$[0-9]+ {
  return ast({
    type: 'Literal',
    valueType: 'integer',
    value: +match,
  });
}

Comment 'comment'
  = BlockComment
  / SingleComment

BlockComment = '{' body:$[^}]+ '}' {
  return ast({type: 'BlockComment', body});
}
SingleComment = '#' body:$[^\n]* '\n' {
  return ast({type: 'SingleComment', body});
}

Punctuation = [-+:;.,()]
