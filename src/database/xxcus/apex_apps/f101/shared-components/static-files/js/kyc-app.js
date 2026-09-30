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
