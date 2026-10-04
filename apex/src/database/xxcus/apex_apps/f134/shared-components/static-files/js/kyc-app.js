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
