class HTMLComponent extends HTMLElement {
    cpName = ''
    constructor() {
        super();
        $(document).ready(() => {
            fetch(`js/components/slider/${this.cpName}.html`).then(async response =>{
                let html = await response.text()
                $(this).append(html)
                this.querySelector('#myRange').onchange = () => this.onValueChange()
                let head = document.getElementsByTagName('head')[0];
                let resource = document.createElement('link');
                resource.rel = 'stylesheet';
                resource.type = 'text/css';
                resource.href = `js/components/slider/${this.cpName}.css`;
                if(this.isResourceLoaded(resource)) {
                    resource = undefined;
                }
                if(resource != undefined) head.appendChild(resource);
                this.attributeChangedCallback();
                this.onReady()
            })
        })
    }

    /** @param {Function} callback */
    setCallback(callback) {
        this.callback = callback
    }
    onReady() {}
    attributeChangedCallback() {}

    isResourceLoaded(resource) {
        let scripts = document.getElementsByTagName('script');
        let links = document.getElementsByTagName('link');
        let elements = undefined;
        if(resource.type == 'text/css') elements = links;
        else if(resource.type == 'text/javascript') elements = scripts;
        let result = false;
        if(elements != undefined) {
            for(el of elements) {
                if(resource.type == 'text/css') {
                    result = el.href == resource.href;
                } else if(resource.type == 'text/javascript') {
                    result = el.src == resource.src;
                }
                if(result) break;
            }
        }
        return result;
    }
}