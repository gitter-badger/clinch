###
This class pack all together with layout

Тут у нас и происходит встройка данных с 
путями и кодом файлов в шаблон, эмулирующий require и export
###

_       = require 'lodash'
async   = require 'async'
fs      = require 'fs'
path    = require 'path'

PACKAGE_FILENAME = path.join __dirname, '..', 'package.json'
RUNTIME_FILENAME = path.join __dirname, '..', 'clinch_runtime.js'

RUNTIME_TARGET_VERSION = 2

class Packer
  constructor: (@_bundle_processor_, @_options_={}) ->
    # for debugging 
    @_do_logging_ = if @_options_.log? and @_options_.log is on and console?.log? then yes else no

    @_settings_ = 
      strict        : @_options_.strict         ? on
      inject        : @_options_.inject         ? on
      runtime       : @_options_.runtime        ? off
      cache_modules : @_options_.cache_modules  ? on

    # will be filled later
    @_clinch_verison_ = null
    @_clinch_runtime_file_content_ = null

  ###
  This method create browser package with given configuration
  ###
  buildPackage : (package_config, main_cb) ->

    @_readSupportFiles (err, files_data) =>
      return main_cb err if err
      [ @_clinch_verison_, @_clinch_runtime_file_content_ ] = files_data
      # so, we are ready, go ahead
      @_bundle_processor_.buildAll package_config, (err, package_code) =>
        return main_cb err if err
        main_cb null, @_assemblePackage package_code, package_config

  ###
  This methos read support files in async manner
  ###
  _readSupportFiles : (main_cb) ->
    async.parallel
      version : (acb) ->
        fs.readFile PACKAGE_FILENAME, 'utf8', (err, data) ->
          return acb err if err?
          try
            json_data = JSON.parse data
          catch error
            return acb error

          if json_data?
            acb null, json_data.version
          else
            acb "no data in |#{PACKAGE_FILENAME}| finded"

      content : (acb) ->
        fs.readFile RUNTIME_FILENAME, 'utf8', acb

      , (err, results) ->
        return main_cb err if err?
        # oh, I get it
        main_cb null, [results.version, results.content]

  ###
  This method assemble result .js file from bundleset
  ###
  _assemblePackage : (package_code, package_config) ->
    # console.log util.inspect package_code, true, null, true

    # prepare environment
    [ env_header, env_body ] = @_buildEnvironment package_code.environment_list, package_code.members

    # set header
    result = @_getHeader env_header, package_config.strict, package_config.cache_modules
    # add dependencies
    result += @_getDependencies package_code.dependencies_tree
    # add sources
    result += @_getSource package_code.source_code
    # add clinch_runtime
    result += @_getBoilerplateJS package_config.runtime
    # add require resolver
    result += @_requireResolver package_config.cache_modules, package_config.runtime
    # add environment body
    result += "\n" + env_body
    # add bundle export
    result += @_getExportDef package_config, package_code
    # add footer
    result + "\n" + @_getFooter()

  ###
  This method build "environment" - local for package variables
  They immitate node.js internal gobal things (like process.nextTick, f.e.)
  ###
  _buildEnvironment : (names, paths) ->
    # just empty strings if no environment
    unless names.length
      return ['','']

    header  = "/* this is environment vars */\nvar " + names.join(', ') + ';'
    
    body    = _.reduce names, (memo, val) ->
      memo += "#{val} = require(#{paths[val]});\n"
    , ''

    [ header, body ]


  ###
  This method create full clinch header
  ###
  _getHeader : (env_header, strict_settings, cache_modules_settings) ->
    """
    
    // Generated by clinch #{@_clinch_verison_}
    (function() {
      #{@_getStrictLine strict_settings}
      #{env_header}
      #{@_getVariableDefinitions cache_modules_settings}
    """

  ###
  This method create dependencies part
  ###
  _getDependencies : (dependencies_tree) ->
    "\n  dependencies = #{JSON.stringify dependencies_tree};\n"

  ###
  This method gather all sources
  ###
  _getSource : (source_obj) ->

    result = "\n  sources = {\n"
    source_index = 0
    for own name, code of source_obj
      result += if source_index++ is 0 then "" else ",\n"
      result += JSON.stringify name
      result += ": function(exports, module, require) {#{code}\n}"
    result += "};\n"

  ###
  This method create export definition part
  ###
  _getExportDef : ({package_name, inject}, package_code) ->

    inject = @_settings_.inject unless inject?
    prefix = @_getMemberPrefix inject

    "\n/* bundle export */\n" + if package_name?
      """
        #{prefix}#{package_name} = {
          #{@_showBundleMembers package_code, '', ':'}
        };
      """
    else
      @_showBundleMembers package_code, prefix, '='


  ###
  This method will show all bundle members for exports part
  ###
  _showBundleMembers : ({bundle_list, members}, member_prefix, delimiter) ->

    members = for bundle_name in bundle_list
      """
      #{member_prefix}#{bundle_name} #{delimiter} require(#{members[bundle_name]})
      """
    
    members.join ",\n"
    
  ###
  This method return  `use 'strict';` line or empty is strict mode supressed
  ###
  _getStrictLine : (isStrict = @_settings_.strict) ->
    if isStrict then "'use strict';" else ''

  ###
  This method return variables definition string
  ###
  _getVariableDefinitions: (isCached = @_settings_.cache_modules) ->
    "var dependencies, sources, require" + ( if isCached then ", modules_cache = {}" else '' ) + ";"

  ###
  This method return bundle prefix, will used to supress bundle injection
  ###
  _getMemberPrefix : (isInject) ->
    if isInject then 'this.' else 'var '

  ###
  This is clinch runtime 
  ###
  _getBoilerplateJS : (isRuntimed = @_settings_.runtime) ->
    if isRuntimed
      """

        if(this.clinch_runtime_v#{RUNTIME_TARGET_VERSION} == null) {
          throw Error("Resolve clinch runtime library version |#{RUNTIME_TARGET_VERSION}| first!");
        }

      """
    else
      "\nvar #{@_clinch_runtime_file_content_}\n"

  ###
  This is short version, MUST be used with runtime js lib
  ###
  _requireResolver: (isCached = @_settings_.cache_modules, isRuntimed = @_settings_.runtime) ->
    prefix = if isRuntimed then 'this.' else ''
    modules_cache_string = if isCached then ', modules_cache' else ''
    "\nrequire = #{prefix}clinch_runtime_v#{RUNTIME_TARGET_VERSION}.require_builder.call(this, dependencies, sources#{modules_cache_string});"

  ###
  This is footer of code wrapper
  ###
  _getFooter : ->
    """
}).call(this);
    """

module.exports = Packer