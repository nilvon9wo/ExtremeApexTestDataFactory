@IsTest
public class XFTY_LiteralExpression implements XFTY_ValueExpressionIntf {
    private final Object value;

    public XFTY_LiteralExpression(Object value) {
        this.value = value;
    }

    public Object get() {
        return this.value;
    }
}