public enum TacticalEvent {
	case spawn(UID)
	case move(UID, CArray<16, XY>)
	case fire(UID, UID, UInt8, UInt8)
	case update(UID)
	case ruggedDefence(XY)
	case shop
	case menu
	case end
}
