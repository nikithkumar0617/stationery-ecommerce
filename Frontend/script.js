const SUPABASE_URL =
"https://bojfqifnbwhavmcrxmkg.supabase.co";

const SUPABASE_KEY =
"sb_publishable_3AIqLVymxDF06OsewH_Byg_V_YZ0atI";

const supabaseClient =
supabase.createClient(
    SUPABASE_URL,
    SUPABASE_KEY
);

async function loadProducts() {

    const { data, error } =
    await supabaseClient
        .from("products")
        .select("*");

    if (error) {
        console.error(error);
        return;
    }

    const container =
        document.getElementById("products-container");

    container.innerHTML = "";

    data.forEach(product => {

        const currentPrice =
            product.discount_price || product.price;

        container.innerHTML += `
        <div class="col-6 col-md-4 col-lg-3">
            <article class="product-card">

                <div class="product-img-wrap">
                    <img
                        src="https://via.placeholder.com/300x300/eeeeee/333333?text=LaLa+Mart"
                        alt="${product.name}"
                        style="
                            width:100%;
                            height:100%;
                            display:block;
                            object-fit:cover;
                        "
                    >
                </div>

                <div class="product-body">

                    <div class="product-brand">
                        ${product.brand}
                    </div>

                    <h3 class="product-name">
                        <a
                            href="product.html?id=${product.id}"
                            style="text-decoration:none;color:inherit;"
                        >
                            ${product.name}
                        </a>
                    </h3>

                    <div class="product-price">

                        <span class="price-current">
                            ₹${currentPrice}
                        </span>

                        ${
                            product.discount_price
                            ? `
                            <span class="price-original">
                                ₹${product.price}
                            </span>
                            `
                            : ""
                        }

                    </div>

                    <div class="product-actions">

                        <button
                        class="btn-add-cart"
                        data-id="${product.id}"
                        data-name="${product.name}"
                        data-price="${currentPrice}"
                        >
                        Add
                        </button>

                        <button class="btn-buy-now">
                            Buy Now
                        </button>

                    </div>

                </div>

            </article>
        </div>
        `;
    });
}

loadProducts();
document.addEventListener("click", (e) => {

    if (!e.target.classList.contains("btn-add-cart")) {
        return;
    }

    const product = {
        id: e.target.dataset.id,
        name: e.target.dataset.name,
        price: e.target.dataset.price
    };

    let cart =
        JSON.parse(localStorage.getItem("cart")) || [];

    cart.push(product);

    localStorage.setItem(
        "cart",
        JSON.stringify(cart)
    );

    updateCartCount();

    alert(product.name + " added to cart");
});

window.addEventListener("load", () => {

    let authMode = "register";

    const registerBtn =
        document.getElementById("registerBtn");

    const loginBtn =
        document.getElementById("loginBtn");

    const closeModal =
        document.getElementById("closeModal");

    const authSubmit =
        document.getElementById("authSubmit");

    registerBtn.addEventListener("click", (e) => {

        e.preventDefault();

        authMode = "register";

        document.getElementById("authTitle")
        .innerText = "Register";

        document.getElementById("authModal")
        .style.display = "block";
    });

    loginBtn.addEventListener("click", (e) => {

        e.preventDefault();

        authMode = "login";

        document.getElementById("authTitle")
        .innerText = "Login";

        document.getElementById("authModal")
        .style.display = "block";
    });

    closeModal.addEventListener("click", () => {

        document.getElementById("authModal")
        .style.display = "none";

    });

    authSubmit.addEventListener("click", async () => {

        const email =
        document.getElementById("authEmail").value;

        const password =
        document.getElementById("authPassword").value;

        if(authMode === "register") {
            const { data, error } =
            await supabaseClient.auth.signUp({
                email,
                password
            });
            console.log(data);
            console.log(error);
            
            if(error) {
                alert(error.message);
            } else {
                alert("Registration Successful");
            }

        } else {
            const { data, error } =
            await supabaseClient.auth.signInWithPassword({
                email,
                password
            });
            
            console.log(data);
            console.log(error);
            
            if(error) {

                alert(error.message);

            } else {

                localStorage.setItem(
                    "userEmail",
                    email
                );
                
                alert("Login Successful");
                location.reload();
            
            }
        }

    });

});

const savedUser =
localStorage.getItem("userEmail");

if(savedUser){
    
    document.getElementById("mobileLoginBtn")
    .style.display = "none";
    
    document.getElementById("mobileRegisterBtn")
    .style.display = "none";

    document.getElementById("loginBtn")
    .innerText = savedUser;

    document.getElementById("registerBtn")
    .innerText = "Logout";

    document.getElementById("registerBtn")
    .addEventListener("click", (e) => {

        e.preventDefault();

        localStorage.removeItem("userEmail");

        alert("Logged Out");

        location.reload();

    });

}


function updateCartCount() {

    const cart =
        JSON.parse(
            localStorage.getItem("cart")
        ) || [];

    const badge =
        document.getElementById("cartCount");

    if(badge){
        badge.innerText = cart.length;
    }
}

updateCartCount();