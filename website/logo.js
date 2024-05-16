function adjustLogo() {
    var windowHeight;
    if (typeof window.visualViewport !== "undefined") {
        windowHeight = window.visualViewport.height;
    } else {
        windowHeight = window.innerHeight;
    }
    var contentHeight = document.getElementById('content').offsetHeight;
    var footerHeight = document.querySelector('footer').offsetHeight;
    var bodyStyles = window.getComputedStyle(document.body);
    var bodyPaddingVertical = parseInt(bodyStyles.paddingTop) + parseInt(bodyStyles.paddingBottom);
    var logoPadding = 60;
    var logoContainerHeight = windowHeight-bodyPaddingVertical-contentHeight-footerHeight-logoPadding;
    var bodyPaddingHorizontal = parseInt(bodyStyles.paddingLeft) + parseInt(bodyStyles.paddingRight);
    var logoContainerWidth = window.innerWidth-bodyPaddingHorizontal-logoPadding;
    var logoSize;
    if(logoContainerWidth > logoContainerHeight) logoSize = logoContainerHeight;
    else logoSize = logoContainerWidth;
    if(logoSize > 400) logoSize = 400;
    if(logoSize < 32) logoSize = 0;
    var logoContainer = document.querySelector('.logoContainer');
    logoContainer.style.height = `${logoSize}px`;
    logoContainer.style.width = `${logoSize}px`;
    var horizontalOffset = logoPadding/2 + (logoContainerWidth - logoSize) / 2;
    var verticalOffset = logoPadding/2 + (logoContainerHeight - logoSize) / 2;
    var logoImage = document.querySelector('.logoImage');
    logoImage.style.paddingLeft = `${horizontalOffset}px`;
    logoImage.style.paddingTop = `${verticalOffset}px`;
}
window.onresize = adjustLogo;
if (window.visualViewport) {
    window.visualViewport.addEventListener('resize', adjustLogo);
}
