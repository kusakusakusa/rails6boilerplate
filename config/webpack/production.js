process.env.NODE_ENV = process.env.NODE_ENV || 'production'

const environment = require('./environment')

// with reference to https://github.com/rails/webpacker/issues/1215#issuecomment-360604583
// use md5 to generate css and js files with same hash
// other methods not working so far
const WebpackMd5Hash = require('webpack-md5-hash')
environment.plugins.append(
  'WebpackMd5Hash',
  new WebpackMd5Hash()
)
environment.config.set('output.filename', '[name]-[chunkhash].js')
environment.config.set('devtool', 'sourcemap')

module.exports = environment.toWebpackConfig()
