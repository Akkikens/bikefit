'use strict';
const { upload } = require('../../lib/handlers');
module.exports = (req, res) => upload(req, res);
