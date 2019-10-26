const { environment } = require('@rails/webpacker')
const erb =  require('./loaders/erb')
const webpack = require('webpack')

environment.plugins.append('Provide', new webpack.ProvidePlugin({
  $: 'jquery',
  jQuery: 'jquery',
  Popper: ['popper.js', 'default'],
  Chart: 'chart.js',
}))

// taking reference from https://gist.github.com/jrunestone/2fbe5d6d5e425b7c046168b6d6e74e95#file-jquery-datatables-webpack
// read more about the AMD and commonjs https://addyosmani.com/writing-modular-js/
environment.loaders.append('import', {
  test: /^datatables\.net.*(?<!css)$/,
  loader: 'imports-loader'
})

environment.loaders.prepend('erb', erb)
module.exports = environment
