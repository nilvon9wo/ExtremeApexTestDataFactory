@IsTest 
public class TEST_DummyDefaultValueUniqueEmail implements TEST_DummyDefaultValueIntf {
    private String prefix;
    private static Integer counter = 1; 
    
    public TEST_DummyDefaultValueUniqueEmail(String prefix) {
    	this.prefix = prefix;
    }  
    
    public Object get() {
    	return this.prefix + counter++ + '@example.com';
    } 
}