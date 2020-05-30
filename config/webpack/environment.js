const { environment } = require('@rails/webpacker')
const erb =  require('./loaders/erb')
const webpack = require('webpack')

environment.plugins.append('Provide', new webpack.ProvidePlugin({
  $: 'jquery',
  jQuery: 'jquery',
  "window.jQuery": "jquery",
  Popper: ['popper.js', 'default']
}))

environment.loaders.prepend('erb', erb)

// making jquery-ui work with jquery https://stackoverflow.com/a/58580434/2667545
const aliasConfig = {
  'jquery': 'jquery-ui-dist/external/jquery/jquery.js',
  'jquery-ui': 'jquery-ui-dist/jquery-ui.js'
};
environment.config.set('resolve.alias', aliasConfig);

module.exports = environment
