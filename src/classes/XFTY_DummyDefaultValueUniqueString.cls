@IsTest
public class XFTY_DummyDefaultValueUniqueString implements XFTY_DummyDefaultValueIntf {
    private String prefix;
    private static Integer counter = 1;

    public XFTY_DummyDefaultValueUniqueString(String prefix) {
        this.prefix = prefix;
    }

    public Object get() {
        return this.prefix + ' ' + counter++;
    }
}