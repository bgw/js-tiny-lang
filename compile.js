'use strict';

const parse = require('./grammar').parse;
const transform = require('./transform');
const recast = require('recast');

let input = '';

process.stdin.on('readable', function() {
  const chunk = process.stdin.read('utf-8');
  if (chunk != null) {
    input += chunk;
  }
});

process.stdin.on('end', function() {
  const ast = transform(parse(input, {location: false}));
  console.log(recast.prettyPrint(ast, {tabWidth: 2}).code);
});
