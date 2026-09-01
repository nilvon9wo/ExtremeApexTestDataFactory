@IsTest
public class XFTY_UniqueEmailExpression implements XFTY_ValueExpressionIntf {
    private final String prefix;
    private static Integer counter = 1;

    public XFTY_UniqueEmailExpression(String prefix) {
        this.prefix = prefix;
    }

    public Object get() {
        return this.prefix + counter++ + '@example.com';
    }
}
