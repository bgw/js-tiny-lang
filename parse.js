'use strict';

const parse = require('./grammar').parse;
const util = require('util');

let input = '';

process.stdin.on('readable', function() {
  const chunk = process.stdin.read('utf-8');
  if (chunk != null) {
    input += chunk;
  }
});

process.stdin.on('end', function() {
  console.log(util.inspect(
    parse(input, {location: false}),
    {showHidden: false, depth: null}
  ));
});
