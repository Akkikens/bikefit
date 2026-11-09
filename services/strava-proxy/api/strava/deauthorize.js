'use strict';
const { deauthorize } = require('../../lib/handlers');
module.exports = (req, res) => deauthorize(req, res);
