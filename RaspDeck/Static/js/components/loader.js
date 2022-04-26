(function() {
    if (!window.jQuery) {  
        var startingTime = new Date().getTime();
        var script = document.createElement("script");
        script.src = 'https://ajax.googleapis.com/ajax/libs/jquery/3.6.0/jquery.min.js';
        script.type = 'text/javascript';
        script.onload = function() {
            var $ = window.jQuery;
        $(function() {
                var endingTime = new Date().getTime();
                var tookTime = endingTime - startingTime;
                console.log("jQuery loaded, after " + tookTime + " milliseconds!");
            });
        };
        document.getElementsByTagName("head")[0].appendChild(script);
    }
})();

function isCSSLinkLoaded(link) {
    return Boolean(link.sheet);
  }

function loadResource(filename, type) {
    let head = document.getElementsByTagName('head')[0];
    let resource = undefined;
    const dir = `js/components/${filename}/${filename}`;
    if(type == 'css') {
        resource = document.createElement('link');
        resource.rel = 'stylesheet';
        resource.type = 'text/css';
        resource.href = dir + '.css';
        if(isCSSLinkLoaded(resource)) {
            resource = undefined;
        }
    } else if(type == 'js') {
        resource = document.createElement("script");
        resource.src = dir + '.js';
        resource.type = 'text/javascript';
    }
    if(resource != undefined) head.appendChild(resource);
}

async function fetchDataAsync(url) {
    const response = await fetch(url);
    return await response.text();
}

async function loadHtml(filename) {
    const url = `js/components/${filename}/${filename}.html`;
    return await fetchDataAsync(url);
}

async function newComponent(cpName) {
    let result = await loadHtml(cpName);
    if(result != undefined) {
        loadResource(cpName, 'css');
        loadResource(cpName, 'js');
        return result;    
    }
    return undefined;
}