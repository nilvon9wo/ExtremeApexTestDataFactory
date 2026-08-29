@IsTest
public class XFTY_DummyDefaultIncrementingDecimal implements XFTY_DummyDefaultValueIntf {
	private Decimal counter = 1;

	public Object get() {
		return counter++;
	}
}