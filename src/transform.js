'use strict';

const js = require('recast').types.builders;

function traverse(node, transformer) {
  if (Array.isArray(node)) {
    if (transformer != null) {
      return node.map(function(el) {
        return traverse(el, transformer);
      });
    }
    // fast code path
    return node.forEach(function(el) { return traverse(el); });
  }
  // only traverse AST objects
  if (typeof node !== 'object' || node === null ||
      !{}.hasOwnProperty.call(node, 'type')) {
    return node;
  }
  // recurse
  if (transformer != null) {
    // clone to avoid in-place transforms
    const result = Object.assign({}, node);
    Object.keys(node).forEach(function(k) {
      result[k] = traverse(node[k], transformer);
    });
    // apply transformer
    return transformer(result);
  }
  // fast code path
  Object.keys(node).forEach(function(k) { traverse(node[k]) });
}

// TODO: finish async transform
function expandAsync(body) {
  const origBody = body.slice();
  for (let i = 0; i < origBody.length; ++i) {
    if (origBody[i].async) {
      origBody[i].async.push(origBody.slice(i + 1));
      body.splice(i + 1);
      expandAsync(origBody[i].async);
      delete origBody[i].async;
      return body;
    }
  }
  return body;
}

const transformations = {
  Tiny(node) {
    const body = [
      js.variableDeclaration(
        'var',
        [
          js.variableDeclarator(
            js.identifier('runtime'),
            js.callExpression(
              js.identifier('require'),
              [js.literal('./runtime')]
            )
          ),
        ]
      ),
      ...node.declarations,
      ...expandAsync([node.body])
    ];
    return js.program(body);
  },

  Declaration({ids, valueType}) {
    const defaultValue = {
      integer: js.literal(0),
      boolean: js.literal(false),
    }[valueType];
    // FYI: type information is thrown away at this point
    return js.variableDeclaration('var', ids.map(function(id) {
      return js.variableDeclarator(id, defaultValue);
    }));
  },

  BlockStatement({body}) {
    // FYI: this may make extranious blocks, so it might make sense to do a
    // cleanup pass afterwards
    return js.blockStatement(expandAsync(body));
  },

  Identifier({name}) {
    return js.identifier('tiny$' + name);
  },

  Literal({value}) {
    // FYI: This may have to be modified if we add new types that don't map
    // one-to-one with JS.
    return js.literal(value);
  },

  AssignmentStatement({left, right}) {
    return js.expressionStatement(js.assignmentExpression('=', left, right));
  },

  ReadExpression(node) {
    return js.callExpression(
      js.memberExpression(js.identifier('runtime'), js.identifier('read')),
      []
    );
  },

  OutputStatement({value}) {
    return js.expressionStatement(
      js.callExpression(
        js.memberExpression(js.identifier('runtime'), js.identifier('output')),
        [value]
      )
    );
  },

  UnaryExpression({operator, argument}) {
    return js.unaryExpression(operator, argument, true);
  },

  BinaryExpression({operator, left, right}) {
    return js.binaryExpression(operator, left, right);
  },

  WhileStatement({test, body}) {
    return js.whileStatement(test, body);
  },

  IfStatement({test, consequent, alternate}) {
    return js.ifStatement(
      test,
      consequent || js.emptyStatement(),
      alternate || js.emptyStatement()
    );
  }
};

module.exports = function transform(ast) {
  return traverse(ast, function(node) {
    if (!{}.hasOwnProperty.call(transformations, node.type)) {
      throw new Error('No transformer for node type: ' + node.type);
    }
    return transformations[node.type](node);
  });
}
