'use strict';

// TODO: finish async transformer and use async readline calls for this
const sget = require('./sget');

module.exports = {
  read() {
    var val = +sget();
    if (~~val !== val) {
      // yes, this works on NaN (given by non-number values)
      throw new Error('expected an integer');
    }
    return val;
  },
  output(value) {
    console.log(value);
  },
}
