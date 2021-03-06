chai = require 'chai'
request = require 'request'
_ = require 'underscore'
async = require 'async'
ajv = require 'ajv'
fs = require 'fs'
glob = require 'glob'

assert = chai.assert
ajv = new ajv


String::contains = (it) ->
  @indexOf(it) != -1


class TestFactory
  create: (name, contentTest) ->
    return new Test(name, contentTest)


class Test
  constructor: (@name, @contentTest) ->
    @name ?= ''
    @skip = false

    @request =
      server: ''
      path: ''
      method: 'GET'
      params: {}
      query: {}
      headers: {}
      body: ''

    @response =
      status: ''
      schema: null
      headers: null
      body: null

    @contentTest ?= (response, body, done) ->
      done()

  url: () ->
    path = @request.server + @request.path

    for key, value of @request.params
      path = path.replace "{#{key}}", value
    return path

  run: (callback) ->
    assertResponse = @assertResponse
    contentTest = @contentTest

    options = _.pick @request, 'headers', 'method'
    options['url'] = @url()
    if typeof @request.body is 'string'
      options['body'] = @request.body
    else
      options['body'] = JSON.stringify @request.body
    options['qs'] = @request.query

    async.waterfall [
      (callback) ->
        request options, (error, response, body) ->
          callback null, error, response, body
      ,
      (error, response, body, callback) ->
        assertResponse(error, response, body)
        contentTest(response, body, callback)
    ], callback

  assertResponse: (error, response, body) =>
    assert.isNull error
    assert.isNotNull response, 'Response'

    # Headers
    @response.headers = response.headers

    # Status code
    assert.equal response.statusCode, @response.status, """
      Got unexpected response code:
      #{body}
      Error
    """
    response.status = response.statusCode

    # Body
    if @response.schema
      schema = @response.schema
      validateJson = _.partial JSON.parse, body
      body = '[empty]' if body is ''

      assert.doesNotThrow validateJson, JSON.SyntaxError, """
        Invalid JSON:
        #{body}
        Error
      """

      json = validateJson()
      result = ajv.validate schema, json

      assert.ok result, """
        Got unexpected response body: #{result.error?.message}
        #{JSON.stringify(json, null, 4)}
        Error
      """

      # Update @response
      @response.body = json


module.exports = TestFactory
