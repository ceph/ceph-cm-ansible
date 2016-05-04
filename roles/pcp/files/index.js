/*jslint indent: 2 nomen: true */
"use strict";

// This is what's in scope at this point
var window, document, ARGS, $, jQuery, moment, kbn, _;

var USAGE = {
  title: "Invalid or missing argument",
  content: "Arguments taken by this dashboard are:\n\n" +
    "``hosts``: A comma-separated list of hosts to monitor (required)\n\n" +
    "``title``: The title of the dashboard (default: the hosts list)\n\n" +
    "``time_from``: The start of the time window (default: 'now-1h')\n\n" +
    "``time_to``: The end of the time window (ignored if time_from is not set)\n\n" +
    "``refresh``: How often to refresh the dashboard (default: never)\n\n" +
    "All arguments are to be passed as a [query string](https://en.wikipedia.org/wiki/Query_string)",
  error: true,
};

// This is the base configuration for the dashboard
var dashboard_stub = {
  rows: [],
  services: {},
  time: {
    from: "now-1h",
    to: "now",
  },
  timezone: "utc",
  editable: "true",
  nav: [
    {
      type: "timepicker",
      collapse: false,
      notice: false,
      enable: true,
      status: "Stable",
      time_options:
        ["5m", "15m", "1h", "6h", "12h", "24h", "2d", "7d", "30d"],
      refresh_intervals:
        ["1m", "5m", "15m", "30m", "1h", "6h", "1d"],
      now: false,
    },
  ],
};

// This is the base configuration for each row
var row_stub = {
  showTitle: true,
  height: '300px',
  panels: [],
};

// This is the base configuration for each panel
var graph_panel_stub = {
  type: 'graph',
  editable: true,
  collapse: false,
  collapsable: true,
  legend_counts: true,
  legend: {
    show: false,
    values: false,
    min: false,
    max: false,
    current: false,
    total: false,
    avg: false
  },
  spyable: true,
  options: false,
};

// This represents each of the panels that we want.
// Each row may contain multiple panels.
// Each panel has a title and one or more metrics.
var dashboard_rows = [
  {
    title: "load (1 minute)",
    panels: [
      {
        metrics: ["kernel.all.load.1 minute"],
      },
    ],
  },
  {
    title: "network (bytes/s)",
    panels: [
      // We use e* here to select only Ethernet interfaces and ignore
      // loopbacks
      {
        title: "in",
        metrics: ["network.interface.in.bytes.e*"],
        span: 6,
      },
      {
        title: "out",
        metrics: ["network.interface.out.bytes.e*"],
        span: 6,
      },
    ],
  },
  {
    title: "disk (kbytes)",
    panels: [
      {
        title: "read",
        metrics: ["disk.all.read_bytes"],
        span: 6,
      },
      {
        title: "write",
        metrics: ["disk.all.write_bytes"],
        span: 6,
      },
    ],
  },
  {
    title: "memory (kbytes)",
    panels: [
      {
        title: "free",
        metrics: ["mem.util.free"],
        span: 6,
      },
      {
        title: "used",
        metrics: ["mem.util.used"],
        span: 6,
      },
    ],
  },
];

var text_panel_stub = {
  title: "",
  type: "text",
  mode: "markdown",
  content: "",
  error: false,
};

function get_text_panel(values) {
  // values is a hash that optionally overrides text_panel_stub's values.
  var panel;
  panel = $.extend(true, text_panel_stub, values);
  return panel;
}

function set_targets(rows_base, hosts) {
  // Now let's flesh out our row values. For each row we want, we need to
  // create a set of 'targets' which consist of wildcarded host values
  // concatenated with each metric we want.
  var i_row, i_panel, i_metric, i_host, row_templ, panel, metrics, metric, host;
  for (i_row = 0; i_row < rows_base.length; i_row += 1) {
    row_templ = rows_base[i_row];
    for (i_panel = 0; i_panel < row_templ.panels.length; i_panel += 1) {
      panel = row_templ.panels[i_panel];
      panel.targets = [];
      metrics = panel.metrics;
      for (i_metric = 0; i_metric < metrics.length; i_metric += 1) {
        metric = metrics[i_metric];
        for (i_host = 0; i_host < hosts.length; i_host += 1) {
          host = hosts[i_host];
          panel.targets.push(
            {target: '*' + host + '*.' + metric}
          );
        }
      }
    }
  }
  return rows_base;
}

function build_dashboard(rows_base) {
  var dashboard, i_row, row_templ, row, i_panel, panel;
  dashboard = $.extend(true, {}, dashboard_stub);
  for (i_row = 0; i_row < rows_base.length; i_row += 1) {
    row_templ = rows_base[i_row];
    row = $.extend(true, {}, row_stub);
    row.title = row_templ.title;
    for (i_panel = 0; i_panel < row_templ.panels.length; i_panel += 1) {
      panel = $.extend(true, {}, graph_panel_stub, row_templ.panels[i_panel]);
      row.panels.push(panel);
    }
    dashboard.rows.push(row);
  }
  return dashboard;
}

function main(callback) {
  var dashboard, hosts, title, rows, panel;
  if (!_.isUndefined(ARGS.hosts)) {
    hosts = ARGS.hosts.split(',');
    // We provide a default title based on the hosts arg, but it may be
    // overridden via the title arg
    title = hosts.join(', ');
    rows = set_targets(dashboard_rows, hosts);
  } else {
    title = 'usage';
    panel = get_text_panel(USAGE);
    rows = [{
      title: "error",
      panels: [panel],
    }];
  }
  dashboard = build_dashboard(rows);
  if (!_.isUndefined(ARGS.refresh)) {
    dashboard.refresh = ARGS.refresh;
  }
  if (!_.isUndefined(ARGS.time_from)) {
    dashboard.time.from = ARGS.time_from;
    if (!_.isUndefined(ARGS.time_to)) {
      dashboard.time.to = ARGS.time_to;
    }
  }
  if (!_.isUndefined(ARGS.title)) {
    title = ARGS.title;
  }
  dashboard.title = title;

  $.ajax({
    method: 'GET',
    url: '/'
  })
    .done(function () {
      callback(dashboard);
    });
}

return main;
