@IsTest
public class XFTY_DummyDefaultValueUniqueEmail implements XFTY_DummyDefaultValueIntf {
    private String prefix;
    private static Integer counter = 1;

    public XFTY_DummyDefaultValueUniqueEmail(String prefix) {
        this.prefix = prefix;
    }

    public Object get() {
        return this.prefix + counter++ + '@example.com';
    }
}