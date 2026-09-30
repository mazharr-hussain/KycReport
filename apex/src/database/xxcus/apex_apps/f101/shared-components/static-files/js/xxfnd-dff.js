/*
 * xxfnd-dff.js - client side of the shared descriptive flexfield region.
 *
 * XXFND_DFF_PKG.RENDER returns the fields; this script
 *   - copies every [data-dff-col] value into the page's JSON item before submit,
 *   - refreshes the region when the user picks another context,
 *   - filters dependent (child) lists when their parent value changes.
 * Usage (page "Execute when Page Loads"):
 *   xxfndDff.bind('party_dff', 'P21_DFF_JSON', 'P21_DFF_CONTEXT');
 */
window.xxfndDff = (function ($) {
    "use strict";

    var bindings = [];

    function collect(regionId) {
        var values = {};
        $("#" + regionId).find("[data-dff-col]").each(function () {
            if (this.disabled) {
                return;
            }
            var v = $(this).val();
            if (v !== null && v !== "") {
                values[$(this).data("dff-col")] = v;
            }
        });
        return JSON.stringify(values);
    }

    function filterChildren(regionId, parentCol) {
        var region = $("#" + regionId),
            parentValue = region.find("[data-dff-col='" + parentCol + "']").val();
        region.find("select[data-dff-parent='" + parentCol + "']").each(function () {
            var child = $(this);
            child.find("option[data-parent-value]").each(function () {
                var show = !parentValue || $(this).data("parent-value") === parentValue;
                $(this).prop("hidden", !show).prop("disabled", !show);
            });
            if (child.find("option:selected").prop("disabled")) {
                child.val("");
            }
        });
    }

    function bind(regionId, jsonItem, contextItem) {
        bindings.push({ region: regionId, json: jsonItem, context: contextItem });
        var region = $("#" + regionId);

        region.on("change", "[data-dff-context-select]", function () {
            apex.item(contextItem).setValue($(this).val());
            apex.region(regionId).refresh();
        });
        region.on("change", "[data-dff-col]", function () {
            filterChildren(regionId, $(this).data("dff-col"));
        });
        region.on("apexafterrefresh", function () {
            region.find("[data-dff-col]").each(function () {
                filterChildren(regionId, $(this).data("dff-col"));
            });
        });
        region.find("[data-dff-col]").each(function () {
            filterChildren(regionId, $(this).data("dff-col"));
        });
    }

    $(apex.gPageContext$).on("apexbeforepagesubmit", function () {
        bindings.forEach(function (b) {
            if ($("#" + b.region).length) {
                apex.item(b.json).setValue(collect(b.region));
            }
        });
    });

    return { bind: bind, collect: collect };
})(apex.jQuery);
