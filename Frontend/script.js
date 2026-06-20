let allProducts = [];

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

    allProducts = data;

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

            const imageUrl =
                product.images &&
                product.images.length > 0
                    ? product.images[0].url
                    : "https://via.placeholder.com/300x300";

        container.innerHTML += `
        <div class="col-6 col-md-4 col-lg-3">
            <article class="product-card">

                <div class="product-img-wrap">
                    <img
                        src="${imageUrl}"
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
                    
                        <span

                            class="cart-controls"
                            data-id="${product.id}"
                            data-name="${product.name}"
                            data-price="${currentPrice}"
                            data-sku="${product.sku}"
                    
                        ></span>
                    
                        <button class="btn-buy-now">
                    
                            Buy Now
                    
                        </button>
                    
                    </div>

                </div>

            </article>
        </div>
        `;

        renderCartControls(product.id);
    });
}

loadProducts();

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
                await supabaseClient
                .from("users")
                .insert([
                    {
                        email: email
                    }
                ]);
                
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

                const { data: dbUser } =
                await supabaseClient
                .from("users")
                .select("id")
                .eq("email", email)
                .single();
                
                if(dbUser){
                    
                    localStorage.setItem(
                        "userId",
                        dbUser.id
                    );
                }
                
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

function getCart() {
    return JSON.parse(
        localStorage.getItem("cart")
    ) || [];
}

function saveCart(cart) {

    localStorage.setItem(
        "cart",
        JSON.stringify(cart)
    );

    updateCartCount();
}

function getQty(id){

    const item =
    getCart().find(
        p => p.id === id
    );

    return item
        ? item.quantity || 0
        : 0;
}

function changeQty(product, delta){

    let cart = getCart();

    const index =
    cart.findIndex(
        p => p.id === product.id
    );

    if(index === -1 && delta > 0){

        cart.push({
            ...product,
            quantity: 1
        });

    } else if(index !== -1){

        cart[index].quantity =
            (cart[index].quantity || 0)
            + delta;

        if(cart[index].quantity <= 0){
            cart.splice(index,1);
        }
    }

    saveCart(cart);

    renderCartControls(product.id);
}

function renderCartControls(id){

    const el =
    document.querySelector(
        `.cart-controls[data-id="${id}"]`
    );

    if(!el) return;

    const qty = getQty(id);

    if(qty > 0){

        el.innerHTML = `
            <button
                class="qty-minus"
                data-id="${id}"
            >
                -
            </button>

            <span
                style="padding:0 10px;"
            >
                ${qty}
            </span>

            <button
                class="qty-plus"
                data-id="${id}"
            >
                +
            </button>
        `;

    } else {

        el.innerHTML = `
            <button
                class="btn-add-cart"
                data-id="${id}"
            >
                Add
            </button>
        `;
    }
}

document.addEventListener("click", (e) => {

    if(e.target.classList.contains("btn-add-cart")){

        const id =
            e.target.dataset.id;

        const card =
            e.target.closest(".product-card");

        const name =
            card.querySelector(".product-name")
            .innerText;

        const price =
            card.querySelector(".price-current")
            .innerText
            .replace("₹","");

        const controls =
            card.querySelector(".cart-controls");
        
        const sku =
            controls.dataset.sku;

        changeQty(
            {
                id:id,
                name:name,
                price:price,
                sku:sku
            },
            1
        );

    }

    if(e.target.classList.contains("qty-plus")){

        const id =
            e.target.dataset.id;

        const cart =
            getCart();

        const item =
            cart.find(
                p => p.id === id
            );

        if(item){
            changeQty(item,1);
        }

    }

    if(e.target.classList.contains("qty-minus")){

        const id =
            e.target.dataset.id;

        const cart =
            getCart();

        const item =
            cart.find(
                p => p.id === id
            );

        if(item){
            changeQty(item,-1);
        }

    }

});

const searchInput =
document.getElementById("searchInput");

if(searchInput){

    searchInput.addEventListener(
        "input",
        function(){

            const searchText =
            this.value.toLowerCase();

            const cards =
            document.querySelectorAll(
                ".product-card"
            );

            cards.forEach(card => {

                const productName =
                card.querySelector(
                    ".product-name"
                )
                .innerText
                .toLowerCase();

                const brandName =
                card.querySelector(
                    ".product-brand"
                )
                .innerText
                .toLowerCase();

                if(
                    productName.includes(searchText)
                    ||
                    brandName.includes(searchText)
                ){

                    card.parentElement.style.display =
                    "block";

                }else{

                    card.parentElement.style.display =
                    "none";

                }

            });

            if(searchText.trim() !== ""){

                document
                .getElementById(
                    "products-container"
                )
                .scrollIntoView({
                    behavior: "smooth"
                });

            }

        }
    );

}