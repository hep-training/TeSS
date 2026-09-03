var Autocompleters = {
    formatResultWithHint: function (suggestion, currentValue) {
        var result = $.Autocomplete.defaults.formatResult(suggestion, currentValue);

        if (suggestion.data && suggestion.data.hint) {
            result += '<span class="autocomplete-hint">' + suggestion.data.hint + '</span>';
        }

        return result;
    },
    transformFunctions: {
        default: function (response, config) {
            var resp = Array.isArray(response) ? response : [];
            return {
                suggestions: $.map(resp, function(item) {
                    var label = item && item[config.labelField];
                    if (label == null) { return null; }
                    return { value: String(label), data: { id: item && item[config.idField], item: item } };
                })
            };
        },
        events: function (response, config) {
            var resp = Array.isArray(response) ? response : [];
            var today = new Date();
            return {
                suggestions: $.map(resp, function(item) {
                    if (!item) { return null; }
                    var group;
                    if (item.end && new Date(item.end) < today) {
                        group = 'Past';
                    } else {
                        group = 'Upcoming';
                    }
                    var hint = null;
                    if (item.start) {
                        hint = item.start.substr(0,10);
                    }
                    var label = item[config.labelField];
                    if (label == null) { return null; }
                    return { value: String(label), data: { id: item[config.idField], group: group, item: item, hint: hint } };
                })
            };
        },
        users: function (response, config) {
            var resp = Array.isArray(response) ? response : [];
            return {
                suggestions: $.map(resp, function (item) {
                    if (!item) { return null; }
                    var name = item.username || '';
                    if (item.firstname) {
                        name = name + " (" + item.firstname + " " + (item.surname || '') + ")";
                    }
                    item.name = name;
                    return { value: String(name), data: { id: item[config.idField], item: item } };
                })
            };
        },
        groups: function (response, config) {
            var resp = Array.isArray(response) ? response : [];
            return {
                suggestions: $.map(resp, function (item) {
                    if (!item) { return null; }
                    var title = item.title;
                    if (title == null) { return null; }
                    return { value: String(title), data: { id: item[config.idField], item: item } };
                })
            };
        },
    },

    init: function () {
        $("[data-role='autocompleter-group']").each(function () {
            Autocompleters.initGroup(this);
        });
    },

    initGroup: function (element, opts) {
        var existingValues = JSON.parse($(element).find('[data-role="autocompleter-existing"]').html()) || [];
        var listElement = $(element).find('[data-role="autocompleter-list"]');
        var inputElement = $(element).find('[data-role="autocompleter-input"]');
        var transformName = $(element).data("transformFunction") || "default";
        var defaults = {
            url: $(element).data("url"),
            prefix: $(element).data("prefix"),
            labelField: $(element).data("labelField") || "title",
            idField: $(element).data("idField") || "id",
            singleton: $(element).data("singleton") || false,
            groupBy: $(element).data("groupBy") || false,
            templateName: $(element).data("template"),
            transformFunction: Autocompleters.transformFunctions[transformName],
            // Allow per-element override via `data-defer-request-by`. Default to 2s for groups, 300ms otherwise.
            deferRequestBy: $(element).data("deferRequestBy") || (transformName === 'groups' ? 2000 : 300)
        };

        var loaderElement = $(element).find('[data-role="autocompleter-loader"]');

        opts = Object.assign({}, defaults, opts);

        // Ensure deferRequestBy is a number (milliseconds)
        opts.deferRequestBy = parseInt(opts.deferRequestBy, 10) || 0;

        // Temporary debug logs to trace requests / loader behavior
        try {
            console.debug('[Autocompleters] initGroup', { url: opts.url, deferRequestBy: opts.deferRequestBy, transformName: transformName });
        } catch (e) { /* no-op in older consoles */ }

        opts.templateName = opts.templateName || (opts.singleton ? "autocompleter/singleton_resource" :
            "autocompleter/resource");

        // Render the existing associations on page load
        if (!listElement.children("li").length) {
            for (var i = 0; i < existingValues.length; i++) {
                listElement.append(HandlebarsTemplates[opts.templateName](existingValues[i]));
            }

            if (opts.singleton && existingValues.length) {
                inputElement.hide();
            }
        }

        inputElement.autocomplete({
            serviceUrl: opts.url,
            dataType: "json",
            deferRequestBy: opts.deferRequestBy,
            // Ensure requests are sent instead of being served from cache
            noCache: true,
            paramName: "q",
            groupBy: opts.groupBy,
            formatResult: Autocompleters.formatResultWithHint,
            transformResult: function(response) {
                try {
                    console.debug('[Autocompleters] transformResult', { responseLength: (response && response.length) || 0, url: opts.url });
                } catch (e) {}
                return opts.transformFunction(response, opts);
            },
            onSelect: function (suggestion) {
                try { console.debug('[Autocompleters] onSelect', suggestion); } catch (e) {}
                // Don't add duplicates
                var id = suggestion.data.id;
                if (!$("[data-id='" + id + "']", listElement).length) {
                    var obj = { item: suggestion.data.item };
                    if (opts.prefix) {
                        obj.prefix = opts.prefix;
                    }

                    listElement.append(HandlebarsTemplates[opts.templateName](obj));
                    if (opts.singleton) {
                        inputElement.hide();
                    }

                    const event = new CustomEvent('autocompleters:added', {  bubbles: true, detail: { object: obj } });
                    listElement[0].dispatchEvent(event);
                }

                $(this).val('').focus();
            },
            onSearchStart: function (query) {
                try { console.debug('[Autocompleters] onSearchStart', { query: query, url: opts.url }); } catch (e) {}
                inputElement.addClass("loading");
                if (loaderElement && loaderElement.length) { loaderElement.show(); }
            },
            onSearchComplete: function () {
                try { console.debug('[Autocompleters] onSearchComplete', { url: opts.url }); } catch (e) {}
                inputElement.removeClass("loading");
                if (loaderElement && loaderElement.length) { loaderElement.hide(); }
            }
        });
    }
}