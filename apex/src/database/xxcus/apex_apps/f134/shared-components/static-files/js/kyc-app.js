/*
 * kyc-app.js - small application-wide behaviours.
 * Navigation-bar "Customize" entry (Theme Style Selection feature): the list entry
 * links to #customize-theme and opens the Universal Theme style dialog.
 */
(function ($) {
    "use strict";
    $(document).on("click", "a[href='#customize-theme']", function (event) {
        event.preventDefault();
        apex.theme.openCustomizationDialog();
    });
})(apex.jQuery);

/*
 * kycQuestionnaire - client side of XXCMP_REQUEST_PKG.QUESTIONNAIRE_HTML (questionnaire form region).
 * Before the page is submitted it copies every answer into the page's JSON item:
 *   [{"q": question_id, "o": answer_option_id, "t": "text"}, ...]
 * The server (ANSWERS_ERROR / SAVE_ANSWERS) re-checks every value.
 * Usage (page load): kycQuestionnaire.bind('answers', 'P202_ANSWERS');
 */
window.kycQuestionnaire = (function ($) {
    "use strict";

    function collect(regionId) {
        var answers = [];
        $("#" + regionId).find("fieldset[data-kyc-q]").each(function () {
            var fs = $(this),
                checked = fs.find("input[type=radio]:checked"),
                input = fs.find(".kyc-q-input");
            answers.push({
                q: Number(fs.data("kyc-q")),
                o: checked.length ? Number(checked.val()) : null,
                t: input.length ? input.val() : null
            });
        });
        return JSON.stringify(answers);
    }

    function bind(regionId, jsonItem) {
        apex.item(jsonItem).setValue(collect(regionId));
        $(apex.gPageContext$).on("apexbeforepagesubmit", function () {
            apex.item(jsonItem).setValue(collect(regionId));
        });
    }

    return { bind: bind, collect: collect };
})(apex.jQuery);

/*
 * kycPerson - employee hover card for list cells (UIUX-STANDARD people rule).
 * A cell shows <span class="kyc-person" data-user="USER_NAME">Employee name</span>; on the first hover or focus the
 * card (name, employee no., department, user name) is loaded once from the PERSON_CARD application process.
 */
(function ($) {
    "use strict";
    $(document).on("mouseenter focusin", ".kyc-person[data-user]:not([data-loaded])", function () {
        var el = $(this).attr("data-loaded", "Y");
        apex.server.process("PERSON_CARD", { x01: el.attr("data-user") }, { dataType: "text" })
            .done(function (html) { el.append(html); });
    });
})(apex.jQuery);

/*
 * kycSectionNav - section menu of a record page (UIUX-STANDARD 5.3, request pages 203 / 205 / 206).
 * When the page has the header card (#record_header), every titled region under it gets a link in a menu on the left:
 * a click jumps to the region on the same page, and the region in view is highlighted while scrolling.
 * On phones the menu is a horizontal strip.
 */
(function ($) {
    "use strict";
    $(function () {
        var header = $("#record_header"), container, regions, nav, list, links = {};
        if (!header.length) { return; }
        container = header.closest(".container");
        regions = container.find(".t-Region").filter(function () {
            var r = $(this);
            return this.id && this.id !== "record_header" && r.parents(".t-Region").length === 0
                && r.is(":visible") && $.trim(r.find(".t-Region-title").first().text()) !== "";
        });
        if (regions.length < 2) { return; }
        nav = $('<nav class="kyc-secnav" aria-label="Sections"><ul></ul></nav>');
        list = nav.find("ul");
        regions.each(function () {
            var a = $('<a></a>').attr("href", "#" + this.id).text($.trim($(this).find(".t-Region-title").first().text()));
            links[this.id] = a;
            list.append($("<li></li>").append(a));
        });
        container.addClass("kyc-has-secnav").prepend(nav);
        header.closest(".row").addClass("kyc-secnav-full");
        nav.on("click", "a", function (e) {
            var t = document.getElementById(this.getAttribute("href").substring(1));
            if (t) { e.preventDefault(); t.scrollIntoView({ behavior: "smooth", block: "start" }); }
        });
        if ("IntersectionObserver" in window) {
            var io = new IntersectionObserver(function (entries) {
                entries.forEach(function (en) {
                    if (en.isIntersecting) {
                        list.find("a").removeClass("is-active");
                        links[en.target.id].addClass("is-active");
                    }
                });
            }, { rootMargin: "-20% 0px -70% 0px" });
            regions.each(function () { io.observe(this); });
        }
        links[regions[0].id].addClass("is-active");
    });
})(apex.jQuery);

/*
 * Dialog buttons: a button with the CSS class "kyc-open-<region static id>" opens that inline dialog
 * (Add Note, Assign, Withdraw on the case screen). The dialog's own button submits the page.
 */
(function ($) {
    "use strict";
    $(document).on("click", "button[class*='kyc-open-']", function (e) {
        var m = this.className.match(/kyc-open-(\S+)/);
        if (m) {
            e.preventDefault();
            apex.theme.openRegion(m[1]);
        }
    });
})(apex.jQuery);

/*
 * Similar parties - ask before saving (party form of the Global Page on pages 23, 24, 201).
 * Before a party is saved (Next / Create / Save) and similar parties exist, a dialog asks: "Confirmed - none of these is
 * this party" (P0_PARTY_MATCH_ACK = Y) or "A possible match exists" (N); then the page is submitted.
 * apex.page.submit is wrapped so the submit waits for the check: cancelling it from an apexbeforepagesubmit handler is not
 * reliable (a nested event resets apex.event.gCancelFlag), and the first submit then also went through - release 29:
 * that created a duplicate request.
 */
(function ($) {
    "use strict";
    var busy = false, original = apex.page.submit;

    function needsCheck(req) {
        var page = String($v("pFlowStepId")), name = apex.item("P0_PARTY_NAME");
        return ["23", "24", "201"].indexOf(page) >= 0 && ["NEXT", "CREATE", "SAVE"].indexOf(req) >= 0
            && $("#party-form").is(":visible") && name.node && name.getValue()
            && !apex.item("P0_PARTY_MATCH_ACK").getValue() && apex.item("P0_PARTY_READ_ONLY").getValue() !== "Y";
    }

    function wrapped(pOptions) {
        var self = this, args = arguments,
            req = (typeof pOptions === "string") ? pOptions : (pOptions && pOptions.request),
            ack = apex.item("P0_PARTY_MATCH_ACK");
        if (!needsCheck(req)) {
            return original.apply(self, args);
        }
        if (busy) { return; }
        busy = true;
        apex.server.process("PARTY_MATCHES", {
            x01: apex.item("P0_PARTY_TYPE").getValue(), x02: apex.item("P0_PARTY_NAME").getValue(),
            x03: apex.item("P0_PARTY_REGISTRATION_NUMBER").getValue(), x04: apex.item("P0_PARTY_INCORPORATION_DATE").getValue(),
            x05: apex.item("P0_PARTY_JURISDICTION").getValue(), x06: apex.item("P0_PARTY_ID").getValue()
        }, { dataType: "json" }).done(function (d) {
            busy = false;
            if (!d || !d.length) { ack.setValue("Y"); original.apply(self, args); return; }
            var list = d.map(function (p) {
                return "- " + p.party_name + " (" + p.party_number + (p.country ? ", " + p.country : "") + ", " + p.score + "%)";
            }).join("\n");
            apex.message.confirm("Similar parties exist:\n" + list + "\n\nIs one of them this party?", function (none) {
                ack.setValue(none ? "Y" : "N");
                original.apply(self, args);
            }, { title: "Possible Matches", style: "warning",
                 confirmLabel: "Confirmed - none of these is this party", cancelLabel: "A possible match exists" });
        }).fail(function () { busy = false; });
    }

    apex.page.submit = wrapped;
    if (apex.submit === original) { apex.submit = wrapped; }
})(apex.jQuery);
