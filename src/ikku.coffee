# Description
#   Add reaction to ultrasoul messages
#
# Configuration:
#   HUBOT_SLACK_IKKU_JIAMARI_REACTION  - set jiamari emoji
#   HUBOT_SLACK_IKKU_JITARAZU_REACTION - set jitarazu emoji
#   HUBOT_SLACK_IKKU_MAX_JIAMARI       - set max jiamari (default. 1)
#   HUBOT_SLACK_IKKU_MAX_JITARAZU      - set max jitarazu (defualt. 0)
#   HUBOT_SLACK_IKKU_MECAB_API_URL     - set mecab-api URL
#   HUBOT_SLACK_IKKU_REACTION          - set reaction emoji (default. flower_playing_cards)
#
# Reference
#   https://github.com/hakatashi/slack-ikku
#
# Author:
#   knjcode <knjcode@gmail.com>

{Promise} = require 'es6-promise'

max = require 'lodash.max'
reduce = require 'lodash.reduce'
tokenize = require 'kuromojin'
unorm = require 'unorm'
util = require 'util'
zipWith = require 'lodash.zipwith'

mecabUrl = process.env.HUBOT_SLACK_IKKU_MECAB_API_URL
if !mecabUrl
  console.error("ERROR: You should set HUBOT_SLACK_IKKU_MECAB_API_URL env variables.")

reaction = process.env.HUBOT_SLACK_IKKU_REACTION ? 'flower_playing_cards'
reaction_jiamari = process.env.HUBOT_SLACK_IKKU_JIAMARI_REACTION
reaction_jitarazu = process.env.HUBOT_SLACK_IKKU_JITARAZU_REACTION
max_jiamari = process.env.HUBOT_SLACK_IKKU_MAX_JIAMARI ? 1
max_jitarazu = process.env.HUBOT_SLACK_IKKU_MAX_JITARAZU ? 0

module.exports = (robot) ->
  checkArrayDifference = (a, b) ->
    tmp = zipWith a, b, (x, y) ->
      x - y
    .map (x) -> max [x, 0]
    reduce tmp, (sum, n) -> sum + n


  mecabTokenize = (unorm_text, robot) -> new Promise (resolve) ->
    data = JSON.stringify {
        "sentence": unorm_text
        "dictionary": 'mecab-ipadic-neologd'
    }
    robot.http(mecabUrl)
      .header("Content-type", "application/json")
      .post(data) (err, res, body) ->
        resolve JSON.parse(body)

  mecabTokenize = (unorm_text, robot) -> new Promise (resolve) ->
    data = JSON.stringify {
        "sentence": unorm_text
        "dictionary": 'mecab-ipadic-neologd'
    }
    robot.http(mecabUrl)
      .header("Content-type", "application/json")
      .post(data) (err, res, body) ->
        resolve JSON.parse(body)

  robot.hear /.*?/i, (msg) ->
    if !mecabUrl
      robot.logger.error("You should set HUBOT_SLACK_IKKU_MECAB_API_URL env variables.")
      return
    unorm_text = unorm.nfkc msg.message.text

    # detect ikku
    mecabTokenize(unorm_text, robot)
    .then (result) ->
      tokens = result.word_list
      targetRegions = [5, 7, 5]
      regions = [0]

      `outer://`
      for token in tokens
        if token.pos is '記号'
          for item in ['、', '!', '?']
            if token.surface_form is item
              if regions.length < targetRegions.length and regions[regions.length - 1] >= targetRegions[regions.length - 1]
                regions.push 0
              `continue outer`

        pronunciation = token.pronunciation or token.surface_form
        return unless pronunciation.match /^[ぁ-ゔァ-ヺー…]+$/

        regionLength = pronunciation.replace(/[ぁぃぅぇぉゃゅょァィゥェォャュョ…]/g, '').length

        if ((token.pos) is '助詞' or (token.pos) is '助動詞') or ((token.pos_detail_1) is '接尾' or (token.pos_detail_1) is '非自立')
          regions[regions.length - 1] += regionLength
        else if (regions[regions.length - 1] < targetRegions[regions.length - 1] or regions.length is 3)
          regions[regions.length - 1] += regionLength
        else
          regions.push(regionLength)

      if regions[regions.length - 1] is 0
        regions.pop

      return if regions.length isnt targetRegions.length

      jiamari = checkArrayDifference regions, targetRegions
      jitarazu = checkArrayDifference targetRegions, regions

      return if jitarazu > max_jitarazu or jiamari > max_jiamari

      robot.adapter.client.web.reactions.add reaction,
        channel: msg.envelope.room
        timestamp: msg.message.id
      .then (res) ->
        robot.logger.info "Found ikku! #{msg.message.text}"
        robot.logger.debug "Add recation #{reaction} ts: #{msg.message.id}, channel: #{msg.envelope.room}, text: #{msg.message.text}"
        addReaction(reaction_jiamari, msg) if jiamari > 0 and reaction_jiamari
        addReaction(reaction_jitarazu, msg) if jitarazu > 0 and reaction_jitarazu
      .catch (error) ->
        robot.logger.error error

    .catch (error) ->
      robot.logger.error error
