
# Data #################################################################################################################

history = []
currentSession = null
dailyTime = 120

# Display Functions ####################################################################################################

refreshAll = ->
    refreshCurrentSession()
    refreshHistory()
    refreshRemaining()

    $('.content').css opacity:1.0

refreshCurrentSession = ->
    $('.current-session').css 'opacity', (if currentSession? then '1.0' else '0.0')
    $('button.checkout').prop 'disabled', currentSession?
    $('button.checkin').prop 'disabled', not currentSession?
    return unless currentSession?

    $('.current-session .start').text currentSession.start.format 'HH:mm'
    $('.current-session .duration').text moment().diff(currentSession.start, 'minutes')

refreshRemaining = ->
    remaining = calculateRemaining()

    hours = remaining.hours()
    minutes = remaining.minutes()
    text = []

    if hours then text.push "#{hours}h "
    text.push "#{minutes}m"

    $('.remaining')
        .text text.join ''
        .css color:(if minutes < 0 then 'red' else '')

    $('.remaining-minutes')
        .text "#{remaining.asMinutes()}m"
        .css opacity:(if hours then '1.0' else '0.0')

refreshHistory = ->
    entriesByDate = collateHistory()

    html = []
    for dateKey, entries of entriesByDate
        continue unless entries.length > 0

        html.push "<h2>#{dateKey}</h2>"

        html.push '<table>'
        html.push """
            <tr>
                <th class="title">title</th>
                <th class="start">start</th>
                <th class="end">end</th>
                <th class="duration">length</th>
                <th class="total">left</th>
            </tr>
        """
        for entry in entries
            if entry.type is 'use'
                html.push '<tr>'
                html.push "<td class=\"title\">#{entry.title}</td>"
                html.push "<td class=\"start\">#{entry.start.format('HH:mm')}</td>"
                html.push "<td class=\"end\">#{entry.end.format('HH:mm')}</td>"
                html.push "<td class=\"duration use\">-#{entry.end.diff(entry.start, 'minutes')}</td>"
                html.push "<td class=\"total\">#{entry.total}</td>"
                html.push '</tr>'
            else if entry.type is 'add'
                html.push '<tr>'
                html.push "<td class=\"title\">#{entry.title}</td>"
                html.push "<td class=\"start\">&nbsp;</td>"
                html.push "<td class=\"end\">&nbsp;</td>"
                html.push "<td class=\"duration add\">#{entry.duration.asMinutes()}</td>"
                html.push "<td class=\"total\">#{entry.total}</td>"
                html.push '</tr>'
        html.push '</table>'

    $('div.history').html html.join('')

# Model Functions ######################################################################################################

ensureDailyAllotment = ->
    today = moment().format 'YYYY-MM-DD'
    for entry in history
        entryKey = entry.start.format 'YYYY-MM-DD'
        return if entryKey is today

    history.push(
        title:    'Daily allotment'
        type:     'add'
        start:    moment().startOf('day')
        duration: moment.duration dailyTime, 'minutes'
    )

checkin = ->
    return unless currentSession?

    end = moment()
    if end.diff(currentSession.start, 'minutes') > 0
        history.push title:'Using screen time', type:'use', start:currentSession.start, end:moment()

    clearInterval currentSession.timer
    currentSession = null

    refreshAll()

checkout = ->
    return if currentSession?

    currentSession = start: moment(), timer: setInterval onSessionTick, 10000

    store()
    refreshAll()

calculateRemaining = ->
    remaining = 0
    for entry in history
        if entry.type is 'add'
            remaining += entry.duration.asMinutes()
        else if entry.type is 'use'
            remaining -= entry.end.diff(entry.start, 'minutes')

    if currentSession?
        remaining -= moment().diff(currentSession.start, 'minutes')

    return moment.duration remaining, 'minutes'

collateHistory = ->
    entries = history[..]
    entries.sort (a, b)-> if a.start < b.start then -1 else +1
    total = 0
    for entry in entries
        if entry.type is 'add'
            total += entry.duration.asMinutes()
        else if entry.type is 'use'
            total -= entry.end.diff entry.start, 'minutes'
        entry.total = total

    entries.sort (a, b)-> if a.start > b.start then -1 else +1
    result = {}
    for entry in entries
        dateKey = entry.start.format 'dddd, MMMM Do'
        result[dateKey] ?= []
        result[dateKey].push entry

    return result

generateSampleData = ->
    d = (value)-> moment.duration value, 'minutes'
    m = (time)-> moment "#{moment().format('YYYY-MM-DD')}T#{time}:00 PDT"

    history = []
    history.push(entry) for entry in [
        { title:'Daily allotment',   type:'add', start:m('00:00'), duration:d(120) }
        { title:'Using screen time', type:'use', start:m('08:01'), end:m('08:15') }
        { title:'Using screen time', type:'use', start:m('09:20'), end:m('10:02') }
        { title:'Using screen time', type:'use', start:m('15:33'), end:m('16:35') }
    ]

    store()
    refreshAll()

    return null

load = ->
    historyJsonText = localStorage.getItem 'history'
    if historyJsonText?
        history = JSON.parse historyJsonText
        for entry in history
            if entry.type is 'use'
                entry.start = moment(entry.start) if entry.start?
                entry.end = moment(entry.end) if entry.end?
            else if entry.type is 'add'
                entry.start = moment(entry.start)
                entry.duration = moment.duration(entry.duration)
    else
        history = []

    currentSessionJsonText = localStorage.getItem 'currentSession'
    if currentSessionJsonText?
        currentSession = JSON.parse currentSessionJsonText
        currentSession.start = moment(currentSession.start)
        currentSession.timer = setInterval onSessionTick, 10000

    refreshAll()

reset = ->
    return unless window.confirm 'Reset all history data?'

    currentSession = null
    history = []
    onSessionTick()

onSessionTick = ->
    ensureDailyAllotment()
    store()
    refreshAll()

store = ->
    localStorage.setItem 'history', JSON.stringify history

    if currentSession?
        localStorage.setItem 'currentSession', JSON.stringify currentSession
    else
        localStorage.removeItem 'currentSession'

########################################################################################################################

$(document).ready ->
    load()
    ensureDailyAllotment()
    refreshAll()

    $('button.checkout').click checkout
    $('button.checkin').click checkin
    $('button.reset').click reset

window.generateSampleData = generateSampleData
window.refresh = refreshAll
