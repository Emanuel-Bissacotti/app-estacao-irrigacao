export class User {
    constructor(
        public uid: string,
        public email: string,
        public emailMqtt: string,
        public passwordMqtt: string,
    ) {}

}