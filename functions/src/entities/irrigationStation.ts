export class IrrigationStation {
  constructor(
    public uid: string,
    public name: string,
    public percentForIrrigation: number,
    public millimetersWater: number,
    public urlMqtt: string
  ) {}
}
