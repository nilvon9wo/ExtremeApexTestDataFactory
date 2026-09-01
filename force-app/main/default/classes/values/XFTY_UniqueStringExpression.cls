@IsTest
public class XFTY_UniqueStringExpression implements XFTY_ValueExpressionIntf {
    private final String prefix;
    private static Integer counter = 1;

    public XFTY_UniqueStringExpression(String prefix) {
        this.prefix = prefix;
    }

    public Object get() {
        return this.prefix + ' ' + counter++;
    }
}