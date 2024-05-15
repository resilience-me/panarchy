function adjustLogo() {
    var windowHeight;
    if (typeof window.visualViewport !== "undefined") {
        windowHeight = window.visualViewport.height;
    } else {
        windowHeight = window.innerHeight;
    }
    var contentDiv = document.getElementById('content');
    var contentHeight = contentDiv.offsetHeight;
    var footerHeight = document.querySelector('footer').offsetHeight;
    var navbarHeight = document.querySelector('.navbar').offsetHeight;

    var contentStyles = window.getComputedStyle(contentDiv);
    var logoPadding = 60;
    var logoContainerHeight = windowHeight-navbarHeight-contentHeight-footerHeight-logoPadding;
    var contentPaddingHorizontal = parseInt(contentStyles.paddingLeft) + parseInt(contentStyles.paddingRight);
    var logoContainerWidth = window.innerWidth-contentPaddingHorizontal-logoPadding;
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
