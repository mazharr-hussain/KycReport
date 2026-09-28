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
