@IsTest
public class XFTY_IncrementingDecimalExpression implements XFTY_ValueExpressionIntf {
	private Decimal counter = 1;

	public Object get() {
		return counter++;
	}
}