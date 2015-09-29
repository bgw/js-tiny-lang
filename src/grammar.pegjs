{
  function unroll(head, tail, idx) {
    if (idx == null) idx = -1;
    return (head === undefined ? [] : [head]).concat(tail.map(function(el) {
      return el[idx < 0 ? el.length + idx : idx];
    }));
  }

  function ast(node) {
    if (options.location) {
      node.location = location();
    }
    return node;
  }

  // Simulates left recursion with right recursion on BinaryExpressions
  function leftRecursive(subtype, node) {
    node._leftRecursiveSubtype = subtype;
    if (node.right._leftRecursiveSubtype === subtype) {
      // rotate  =>   to be
      //   B            D
      //  / \          / \
      // A   D        B   F
      //    / \      / \
      //   C   F    A   C
      const tmp = node;
      node = node.right;
      tmp.right = node.left;
      node.left = tmp;
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

Whitespace 'whitespace'
  = $[ \t\v\f\r\n]+

Comment 'comment'
  = BlockComment
  / SingleComment

// mandatory whitespace
__ 'whitespace'
  = Whitespace? Comment _
  / Whitespace
// optional whitespace
_ = __?

Declarations
  = VarKeyword dclns:(_ Declaration)* { return unroll(undefined, dclns); }
  / '' { return []; }

Declaration = ids:DeclarationNames _ ':' _ valueType:Type _ ';' {
  return ast({type: 'Declaration', ids, valueType});
}
DeclarationNames
  = names:(
    head:Identifier tail:(_ ',' _ Identifier)*
    { return unroll(head, tail); }
  )?
  { return names || []; }

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

AssignmentStatement = left:Identifier _ ':=' _ right:Expression {
  return ast({type: 'AssignmentStatement', left, right});
}

OutputStatement =
  OutputKeyword _ '(' _ head:Expression tail:(_ ',' _ Expression)* _ ')'
  {
    return ast({type: 'OutputStatement', arguments: unroll(head, tail)});
  }

// There is the dangling-else problem, but since this is an LL(1) parser, this
// gets resolved cleanly, giving the innermost `if` control of the else.
IfStatement
  = IfKeyword _ test:Expression
  _ ThenKeyword _ consequent:Statement
  alternate:(_ ElseKeyword _ s:Statement { return s; })?
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

// Expression is broken up into multiple "levels" that enforce precedence and
// varying associativity
Expression
  = left:AddExpression
  _ operator:$('<=' / '>=' / '<' / '>' / '=' / '<>')
  _ right:AddExpression
  { return ast({type: 'BinaryExpression', operator, left, right}); }
  / AddExpression

// While the grammar is written as as right-recursive, the result is actually
// transformed to left-recursive using a helper function.
AddExpression
  = left:MultExpression
  _ operator:$('-' / '+' / OrKeyword)
  _ right:AddExpression
  {
    return leftRecursive('AddExpression',
      ast({type: 'BinaryExpression', operator, left, right})
    );
  }
  / MultExpression

// Actually left-recursive. See previous comment.
MultExpression
  = left:UnaryExpression
  // we have to special-case '**' to avoid overlapping with PowExpression
  _ operator:$(('*' !'*') / '/' / AndKeyword / ModKeyword)
  _ right:MultExpression
  {
    return leftRecursive('MultExpression',
      ast({type: 'BinaryExpression', operator, left, right})
    );
  }
  / UnaryExpression

// Normally, a UnaryExpression would have higher precedence than PowExpression,
// that's not true in this language.
UnaryExpression
  = operator:$('-' / '+' / NotKeyword) _ argument:UnaryExpression
  { return ast({type: 'UnaryExpression', operator, argument}); }
  / PowExpression

// Yes, this is right-recursive, though in a serious language, it wouldn't be
PowExpression
  = left:PrimaryExpression _ operator:$'**' _ right:PowExpression
  {
    return leftRecursive('MultExpression',
      ast({type: 'BinaryExpression', operator, left, right})
    );
  }
  / PrimaryExpression

// prevents left-recursion for BinaryExpression
PrimaryExpression
  = Identifier
  / Literal
  / ReadKeyword { return ast({type: 'ReadExpression'}); }
  / EofKeyword { return ast({type: 'EofExpression'}); }
  / '(' _ sub:Expression _ ')' { return sub; }

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
  / EofKeyword
  / OrKeyword
  / AndKeyword
  / ModKeyword
  / NotKeyword
  / TrueKeyword
  / FalseKeyword

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
EofKeyword =        $('eof'     !IdentifierPart)
OrKeyword =         $('or'      !IdentifierPart)
AndKeyword =        $('and'     !IdentifierPart)
ModKeyword =        $('mod'     !IdentifierPart)
NotKeyword =        $('not'     !IdentifierPart)
TrueKeyword =       $('true'    !IdentifierPart)
FalseKeyword =      $('false'   !IdentifierPart)

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
  / kw:$(TrueKeyword / FalseKeyword) {
    return ast({type: 'Literal', valueType: 'boolean', value: kw === 'true'});
  }

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

BlockComment = '{' body:$[^}]+ '}' {
  return ast({type: 'BlockComment', body});
}
SingleComment = '#' body:$[^\n]* '\n' {
  return ast({type: 'SingleComment', body});
}

Punctuation = [-+:;.,()]
