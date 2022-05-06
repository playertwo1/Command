class G5Slider extends HTMLComponent {
    cpName = 'slider'
    constructor() {
        super();
    }

    static get observedAttributes() {
        return ['icon']
    }

    /** @returns {string} */
    get icon() { return this.getAttribute('icon') }
    /** @param {string} val */
    set icon(val) { this.setAttribute('icon', val) }

    /**
     * Called when a attribute has changed
     * @param {string} name the attribute name
     * @param {string} oldVal the old attribute value
     * @param {string} newVal the new attribute value
     */
    attributeChangedCallback(name, oldVal, newVal) {
        try {
            if(this.icon != null && this.icon != undefined) {
                this.querySelector('#icone').setAttribute('src', this.icon)
            } else {
                $(this.querySelector('#icone')).hide()
            }
            this.querySelector("#myRange").setAttribute('orient', this.getAttribute('orient'))
        } catch (error) {}
    }

    onValueChange() {
        if(this.callback != undefined) {
            this.callback(this.querySelector('#myRange').value)
        } else {
            console.log(this.querySelector('#myRange').value)
        }
    }
}

window.customElements.define('g5-slider', G5Slider);