'use strict';
const { refresh } = require('../../lib/handlers');
module.exports = (req, res) => refresh(req, res);
