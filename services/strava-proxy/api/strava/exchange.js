'use strict';
const { exchange } = require('../../lib/handlers');
module.exports = (req, res) => exchange(req, res);
